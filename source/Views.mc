import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Current fix as [latDeg, lonDeg] Doubles, or null if we have no usable fix yet.
function currentLatLon() as Array<Double>? {
    var info = $.gLastInfo;
    if (info == null || info.position == null) {
        return null;
    }
    var d = info.position.toDegrees();   // [lat, lon] as Doubles
    return [d[0].toDouble(), d[1].toDouble()] as Array<Double>;
}

//! Home screen: where you are, in plain language, plus how to open the tools.
//! Lays out around the grid block so it stays legible from 280px down to 156px.
class MainView extends WatchUi.View {

    // The "TOOLS" hint fades after the shared hint window; it comes back each
    // time you return to the home screen.
    private var _hints as HintTimer = new HintTimer();

    public function initialize() {
        View.initialize();
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
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);

        // App name near the top arc.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.13).toNumber(), Graphics.FONT_XTINY, "GRIDRECON", vc);

        drawButtonHint(dc, 0.32, true, "TOOLS", Graphics.COLOR_WHITE, true);

        var ll = currentLatLon();
        if (ll == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for GPS…", vc);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY, "step outside for a fix", vc);
            return;
        }

        // Grid is the hero; place the label above it and the hint below it.
        var grid = Geo.latLonToMgrs(ll[0], ll[1]);
        var half = drawGridFitted(dc, cx, cy, grid, Graphics.COLOR_WHITE, (w * 0.9).toNumber());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - half - tinyH / 2, Graphics.FONT_TINY, "You are at", vc);

    }
}

//! Home-screen input: START (or MENU) opens the tools menu.
class MainDelegate extends WatchUi.BehaviorDelegate {

    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onSelect() as Boolean {
        openToolMenu();
        return true;
    }

    public function onMenu() as Boolean {
        openToolMenu();
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

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var entered = "bearing " + _azDeg.toNumber().format("%03d") + "°  ·  " + _rangeM.toNumber().format("%d") + " m";
        dc.drawText(cx, gy + half + xtinyH / 2 + 2, Graphics.FONT_XTINY, entered, vc);

        var back = Geo.backAzimuth(_azDeg);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, gy + half + xtinyH * 3 / 2 + 4, Graphics.FONT_XTINY,
            "walk back on " + back.toNumber().format("%03d") + "°", vc);

        drawButtonHint(dc, 0.32, true, "GO", Graphics.COLOR_WHITE, true);     // timed
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false); // always-on
    }
}

//! Result-screen input: START navigates to the computed target; BACK returns.
class ResultDelegate extends WatchUi.BehaviorDelegate {

    private var _destLat as Double;
    private var _destLon as Double;

    public function initialize(destLat as Double, destLon as Double) {
        BehaviorDelegate.initialize();
        _destLat = destLat;
        _destLon = destLon;
    }

    public function onSelect() as Boolean {
        var v = new ReturnNavView("Target", _destLat, _destLon);
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
