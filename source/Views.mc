import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Current fix as [latDeg, lonDeg] Doubles, or null if we have no position at all.
//! NOTE: this returns a cached last-known position too - use hasFreshFix() to tell
//! whether it's trustworthy enough to compute a mark/target from.
function currentLatLon() as Array<Double>? {
    var info = $.gLastInfo;
    if (info == null || info.position == null) {
        return null;
    }
    var d = info.position.toDegrees();   // [lat, lon] as Doubles
    return [d[0].toDouble(), d[1].toDouble()] as Array<Double>;
}

//! Format a position per the user's coordinate setting: an MGRS grid (at the chosen
//! precision), decimal lat/long, or a plain UTM grid. Used everywhere a coordinate
//! is shown.
function formatPosition(lat as Double, lon as Double) as String {
    if (Settings.useLatLon()) {
        return lat.format("%.5f") + ", " + lon.format("%.5f");
    }
    if (Settings.useUtm()) {
        return Geo.latLonToUtmString(lat, lon);
    }
    return Geo.mgrsAtPrecision(lat, lon, Settings.gridDigits());
}

//! Altitude of the latest fix in metres above sea level, or null if we have none
//! (no fix yet, or the receiver didn't report altitude).
function currentElevationM() as Float? {
    var info = $.gLastInfo;
    if (info == null || info.altitude == null) {
        return null;
    }
    return info.altitude;
}

//! Elevation in the user's units: metric "1280 m", imperial "4199 ft".
function formatElevation(m as Float) as String {
    if (Settings.useImperial()) {
        return (m / 0.3048).format("%.0f") + " ft";
    }
    return m.format("%.0f") + " m";
}

//! Draw the current elevation (when the fix carries it) centered low on the screen,
//! near the bottom arc. That zone is empty on the home and mark screens and clear of
//! the side button hints, so the elevation never crowds the grid block or the actions.
//! No-op when there's no altitude. Shared by MainView and MarkView.
function drawElevation(dc as Dc) as Void {
    var elev = currentElevationM();
    if (elev == null) {
        return;
    }
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawText(dc.getWidth() / 2, (dc.getHeight() * 0.84).toNumber(), Graphics.FONT_XTINY,
        "elev " + formatElevation(elev),
        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
}

//! Quality of the latest fix (NOT_AVAILABLE if we have none yet).
function fixAccuracy() as Position.Quality {
    var info = $.gLastInfo;
    if (info == null) {
        return Position.QUALITY_NOT_AVAILABLE;
    }
    return info.accuracy;
}

//! Seconds since the latest fix was taken, or -1 if unknown. With continuous GPS
//! this is normally 0-2 s; it only grows when fixes stop arriving (indoors, canyon).
function fixAgeSec() as Number {
    var info = $.gLastInfo;
    if (info == null || info.when == null) {
        return -1;
    }
    return Time.now().value() - info.when.value();
}

//! Beyond this age a fix is treated as stale even if its last quality was good.
//! `accuracy` keeps its old value after GPS is powered down, so without this an
//! abandoned fix would still look "fresh" and a mark could be saved at a position
//! the watch left long ago. With GPS held this never trips (fixes arrive every
//! 1-2 s); it only catches a receiver that has stopped delivering.
const FRESH_MAX_AGE_SEC = 30;

//! True if we have a fresh, usable fix - not just a cached or frozen position.
//! The compute tools gate on this so a mark/target isn't built on stale data.
function hasFreshFix() as Boolean {
    if (fixAccuracy() < Position.QUALITY_POOR) {
        return false;
    }
    var age = fixAgeSec();
    return age < 0 || age <= FRESH_MAX_AGE_SEC;   // age < 0 = unknown, fall back to quality
}

//! Short status word for the current fix quality.
function gpsText(q as Position.Quality) as String {
    if (q == Position.QUALITY_GOOD)       { return "GPS good"; }
    if (q == Position.QUALITY_USABLE)     { return "GPS ok"; }
    if (q == Position.QUALITY_POOR)       { return "GPS poor"; }
    if (q == Position.QUALITY_LAST_KNOWN) { return "last known"; }
    return "no GPS";
}

//! Status colour: white when trustworthy, yellow as a caution. (Green is avoided -
//! it maps to the background and vanishes on 1-bit Instinct displays.)
function gpsColor(q as Position.Quality) as Graphics.ColorType {
    if (q == Position.QUALITY_GOOD || q == Position.QUALITY_USABLE) {
        return Graphics.COLOR_WHITE;
    }
    return Graphics.COLOR_YELLOW;
}

//! Home screen: where you are, in plain language, plus how to open the tools.
//! Lays out around the grid block so it stays legible from 280px down to 156px.
class MainView extends WatchUi.View {

    // The "TOOLS" hint fades after the shared hint window; it comes back each
    // time you return to the home screen.
    private var _hints as HintTimer = new HintTimer();
    private var _refresh as Timer.Timer?;   // redraw while waiting for a fix / ageing
    private var _shownAt as Number = 0;      // when this screen last appeared (ms)

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        _hints.reset();
        gpsAcquire();
        _shownAt = System.getTimer();
        // Keep the screen live so a fix appears promptly, the age updates, and the
        // no-fix guidance can escalate even when no position events are arriving.
        _refresh = new Timer.Timer();
        _refresh.start(method(:onRefresh), 3000, true);
    }

    public function onHide() as Void {
        _hints.stop();
        gpsRelease();
        if (_refresh != null) {
            _refresh.stop();
            _refresh = null;
        }
    }

    public function onRefresh() as Void {
        WatchUi.requestUpdate();
    }

    //! Re-show the hints (called when a button is pressed on this screen).
    public function bumpHints() as Void {
        _hints.reset();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        // App name near the top arc.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.13).toNumber(), Graphics.FONT_XTINY, "GRIDRECON", vc);

        drawButtonHint(dc, 0.32, true, "TOOLS", Graphics.COLOR_WHITE, true);

        var ll = currentLatLon();
        if (ll == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for GPS…", vc);
            // After a while with no fix at all, point at the likely causes - outdoors
            // line of sight, or the Location/GPS permission being off.
            var waited = System.getTimer() - _shownAt;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (waited > 20000) {
                dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY,
                    "go outside, and check\nLocation/GPS is enabled", vc);
            } else {
                dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY, "step outside for a fix", vc);
            }
            return;
        }

        // Grid is the hero; place the label above it and the GPS status below it.
        // When the fix is only last-known (stale cache), dim the grid so it doesn't
        // read as a trustworthy live position.
        var q = fixAccuracy();
        var fresh = hasFreshFix();
        var gridColor = fresh ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
        var grid = formatPosition(ll[0], ll[1]);
        var half = drawGridFitted(dc, cx, cy, grid, gridColor, (w * 0.9).toNumber());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - half - tinyH / 2, Graphics.FONT_TINY, "You are at", vc);

        // GPS status line: quality, plus fix age when fixes have stopped arriving.
        var status = gpsText(q);
        var age = fixAgeSec();
        if (fresh && age > 10) {
            status += " · " + age.format("%d") + "s old";
        }
        dc.setColor(gpsColor(q), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + half + xtinyH / 2 + 4, Graphics.FONT_XTINY, status, vc);

        // Elevation sits down by the bottom arc, away from the grid/status cluster.
        drawElevation(dc);
    }
}

//! Home-screen input: START (or MENU) opens the tools menu. UP/DOWN just bring
//! the hint back (they otherwise do nothing on this screen).
class MainDelegate extends ButtonNavDelegate {

    private var _view as MainView;

    public function initialize(view as MainView) {
        ButtonNavDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        openToolMenu();
        return true;
    }

    public function onMenu() as Boolean {
        openToolMenu();
        return true;
    }

    public function onPreviousPage() as Boolean {
        _view.bumpHints();
        return true;
    }

    public function onNextPage() as Boolean {
        _view.bumpHints();
        return true;
    }
}

//! "Mark this spot": a live screen that holds GPS itself and shows where you are
//! right now, so the position you save is current - not a fix frozen at the spot
//! where you opened the menu. SAVE captures the live fix and goes on to pick a name.
class MarkView extends WatchUi.View {

    private var _hints as HintTimer = new HintTimer();
    private var _refresh as Timer.Timer?;   // redraw while the fix converges / ages
    private var _shownAt as Number = 0;      // when this screen last appeared (ms)

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        _hints.reset();
        gpsAcquire();
        _shownAt = System.getTimer();
        _refresh = new Timer.Timer();
        _refresh.start(method(:onRefresh), 1000, true);
    }

    public function onHide() as Void {
        _hints.stop();
        gpsRelease();
        if (_refresh != null) {
            _refresh.stop();
            _refresh = null;
        }
    }

    public function onRefresh() as Void {
        WatchUi.requestUpdate();
    }

    //! Re-show the hints (called when a button is pressed on this screen).
    public function bumpHints() as Void {
        _hints.reset();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.13).toNumber(), Graphics.FONT_XTINY, "MARK HERE", vc);

        var ll = currentLatLon();
        // Only let the user save a fix that is fresh AND current - a stale or cached
        // position would mark the wrong spot, which is the whole point of this screen.
        if (ll == null || !hasFreshFix()) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for GPS…", vc);
            var waited = System.getTimer() - _shownAt;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            if (waited > 20000) {
                dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY,
                    "go outside, and check\nLocation/GPS is enabled", vc);
            } else {
                dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY, "step outside for a fix", vc);
            }
            drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
            return;
        }

        // Live position is the hero, exactly as the home screen shows it, so the user
        // can confirm they have moved before committing the mark.
        var grid = formatPosition(ll[0], ll[1]);
        var half = drawGridFitted(dc, cx, cy, grid, Graphics.COLOR_WHITE, (w * 0.9).toNumber());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - half - tinyH / 2, Graphics.FONT_TINY, "You are at", vc);

        var q = fixAccuracy();
        dc.setColor(gpsColor(q), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + half + xtinyH / 2 + 4, Graphics.FONT_XTINY, gpsText(q), vc);

        // Elevation sits down by the bottom arc, clear of the side button hints.
        drawElevation(dc);

        // Always-on so the action is never hidden by the hint fade.
        drawButtonHint(dc, 0.32, true, "SAVE", Graphics.COLOR_WHITE, false);
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
    }
}

//! Mark-screen input: START saves the live position (then pick a name); BACK exits.
//! UP/DOWN just bring the hints back.
class MarkDelegate extends ButtonNavDelegate {

    private var _view as MarkView;

    public function initialize(view as MarkView) {
        ButtonNavDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        var ll = currentLatLon();
        if (ll == null || !hasFreshFix()) {
            // No current fix yet - the screen already says so; keep the hints up.
            _view.bumpHints();
            return true;
        }
        showMarkNameMenu(ll[0], ll[1]);
        return true;
    }

    public function onPreviousPage() as Boolean {
        _view.bumpHints();
        return true;
    }

    public function onNextPage() as Boolean {
        _view.bumpHints();
        return true;
    }
}

//! Result screen: the target's grid in plain language, with the numbers you
//! entered and the bearing to walk back to where you stood.
class ResultView extends WatchUi.View {

    private var _targetGrid as String;
    private var _azDeg as Double;
    private var _rangeM as Double;
    private var _hints as HintTimer = new HintTimer();

    public function initialize(targetGrid as String, azDeg as Double, rangeM as Double) {
        View.initialize();
        _targetGrid = targetGrid;
        _azDeg = azDeg;
        _rangeM = rangeM;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    //! Re-show the hints (called when a button is pressed on this screen).
    public function bumpHints() as Void {
        _hints.reset();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        // Grid sits at true vertical center - the one zone that stays clear of the
        // Instinct's carved-out sub-window. Label goes above, details below.
        // Yellow, not green: on 1-bit monochrome Instinct displays green maps to
        // the background and vanishes, whereas yellow maps to the foreground.
        var gy = cy;
        var half = drawGridFitted(dc, cx, gy, _targetGrid, Graphics.COLOR_YELLOW, (w * 0.9).toNumber());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, gy - half - tinyH / 2, Graphics.FONT_TINY, "Target is at", vc);

        // Bearings are shown in the user's angle unit, with a trailing "M" when a
        // declination offset is in effect (a magnetic reading); with no offset
        // everything is true north and the marker is dropped. _azDeg is already in the
        // magnetic frame, so formatBearing just tags it - it doesn't re-apply the offset.
        var mag = Settings.hasDeclination();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var entered = "bearing " + Settings.formatBearing(_azDeg, mag) + "  ·  " + formatDistance(_rangeM);
        dc.drawText(cx, gy + half + xtinyH / 2 + 2, Graphics.FONT_XTINY, entered, vc);

        var back = Geo.backAzimuth(_azDeg);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, gy + half + xtinyH * 3 / 2 + 4, Graphics.FONT_XTINY,
            "walk back on " + Settings.formatBearing(back, mag), vc);

        drawButtonHint(dc, 0.32, true, "GO", Graphics.COLOR_WHITE, true);      // START, timed
        drawButtonHint(dc, 0.47, false, "SAVE", Graphics.COLOR_WHITE, true);   // UP, timed
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false); // always-on
    }
}

//! Result-screen input: START navigates to the computed target; BACK returns.
//! UP/DOWN just bring the hints back.
class ResultDelegate extends ButtonNavDelegate {

    private var _view as ResultView;
    private var _destLat as Double;
    private var _destLon as Double;

    public function initialize(view as ResultView, destLat as Double, destLon as Double) {
        ButtonNavDelegate.initialize();
        _view = view;
        _destLat = destLat;
        _destLon = destLon;
    }

    //! UP saves the computed target as a mark (so you can return to it later);
    //! DOWN just brings the hints back.
    public function onPreviousPage() as Boolean {
        showMarkNameMenu(_destLat, _destLon);
        return true;
    }

    public function onNextPage() as Boolean {
        _view.bumpHints();
        return true;
    }

    public function onSelect() as Boolean {
        var v = new ReturnNavView("Target", _destLat, _destLon);
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}

//! Shows a computed *place* as a grid (e.g. the spot you resected): the grid is the
//! hero, with a one-word label above. GO navigates to it, SAVE stores it as a mark to
//! return to later, and BACK returns - the same START/UP/BACK trio as the target
//! result screen, so the actions land on the buttons you already know.
class PlaceResultView extends WatchUi.View {

    private var _label as String;
    private var _grid as String;
    private var _hints as HintTimer = new HintTimer();

    public function initialize(label as String, grid as String) {
        View.initialize();
        _label = label;
        _grid = grid;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    public function bumpHints() as Void {
        _hints.reset();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);

        var half = drawGridFitted(dc, cx, cy, _grid, Graphics.COLOR_YELLOW, (w * 0.9).toNumber());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - half - tinyH / 2, Graphics.FONT_TINY, _label, vc);

        drawButtonHint(dc, 0.32, true, "GO", Graphics.COLOR_WHITE, true);       // START, timed
        drawButtonHint(dc, 0.47, false, "SAVE", Graphics.COLOR_WHITE, true);    // UP, timed
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);  // always-on
    }
}

//! Place-result input: START navigates to the place, UP saves it as a mark (pick a
//! name), BACK returns. Mirrors ResultDelegate so the buttons behave the same way.
class PlaceResultDelegate extends ButtonNavDelegate {

    private var _view as PlaceResultView;
    private var _lat as Double;
    private var _lon as Double;
    private var _navName as String;

    public function initialize(view as PlaceResultView, lat as Double, lon as Double, navName as String) {
        ButtonNavDelegate.initialize();
        _view = view;
        _lat = lat;
        _lon = lon;
        _navName = navName;
    }

    //! START: navigate to the computed place.
    public function onSelect() as Boolean {
        var v = new ReturnNavView(_navName, _lat, _lon);
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! UP: save the place as a mark to return to later.
    public function onPreviousPage() as Boolean {
        showMarkNameMenu(_lat, _lon);
        return true;
    }

    public function onNextPage() as Boolean {
        _view.bumpHints();
        return true;
    }
}

//! Shows a *relationship* between two points (e.g. grid-to-grid): the distance is the
//! hero, with the bearing to steer and the back-azimuth below. Read-only; BACK returns.
class RangeResultView extends WatchUi.View {

    private var _distM as Double;
    private var _bearingTrue as Double;
    private var _label as String;
    private var _hints as HintTimer = new HintTimer();

    public function initialize(label as String, distM as Double, bearingTrue as Double) {
        View.initialize();
        _label = label;
        _distM = distM;
        _bearingTrue = bearingTrue;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.18).toNumber(), Graphics.FONT_TINY, _label, vc);

        // Distance is the hero; the bearing is shown in the user's unit, magnetic (the
        // number to dial on a compass) when a declination offset is set, true otherwise.
        var mag = Settings.hasDeclination();
        var steer = Settings.trueToMag(_bearingTrue);
        var back = Geo.backAzimuth(_bearingTrue);
        var backSteer = Settings.trueToMag(back);

        var numH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - numH / 4, Graphics.FONT_NUMBER_MEDIUM, formatDistance(_distM), vc);

        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + numH / 2 + xtinyH, Graphics.FONT_XTINY,
            "bearing " + Settings.formatBearing(steer, mag), vc);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + numH / 2 + xtinyH * 2, Graphics.FONT_XTINY,
            "back " + Settings.formatBearing(backSteer, mag), vc);

        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
    }
}
