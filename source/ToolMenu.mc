import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Build and show the tools menu. Called from the home screen. Routed through
//! showMenu so it honours the buttons-only setting (custom list vs native Menu2).
function openToolMenu() as Void {
    var items = [
        {"label" => "Mark this spot", "sub" => "save where you are",     "id" => :mark},
        {"label" => "Take me back",   "sub" => "navigate to a mark",     "id" => :back},
        {"label" => "Manage marks",   "sub" => "delete a mark",          "id" => :manage},
        {"label" => "Find a target",  "sub" => "where is that thing?",   "id" => :target},
        {"label" => "Go to a grid",   "sub" => "navigate to an MGRS grid", "id" => :gogrid},
        {"label" => "Settings",       "sub" => "input · coords · units", "id" => :settings},
        {"label" => "Help",           "sub" => "how this works",         "id" => :help},
        {"label" => "About",          "sub" => null,                     "id" => :about}
    ] as Array<Dictionary>;
    showMenu("Tools", items, new ToolMenuHandler().method(:onChoose));
}

class ToolMenuHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        if (id == :target) {
            new TargetLocationFlow().start();
        } else if (id == :gogrid) {
            startGoToGrid();
        } else if (id == :mark) {
            startMarkFlow();
        } else if (id == :back) {
            startTakeMeBack();
        } else if (id == :manage) {
            startManageMarks();
        } else if (id == :settings) {
            openSettingsMenu();
        } else if (id == :help) {
            var v = new MessageView("How it works",
                "Point your compass at\nsomething. Read the\nbearing & how far it is.\nEnter them and you get\nits map grid.");
            WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :about) {
            var v = new MessageView("GridRecon  v1.3.0",
                "Land navigation when\nGPS is off or jammed.\nMore tools coming.");
            WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

//! "Find a target": from a starting point, sight the compass bearing and enter the
//! distance to a target, then compute and show the target's map grid. The starting
//! point is the live fix when there is one - but if GPS is off or jammed (the whole
//! point of the app) you can enter your position by grid and the geometry still works.
class TargetLocationFlow {

    private var _fromLat as Double = 0.0d;
    private var _fromLon as Double = 0.0d;
    private var _azMag as Double = 0.0d;    // bearing as entered, in magnetic-frame DEGREES

    public function initialize() {
    }

    public function start() as Void {
        var ll = currentLatLon();
        if (ll != null && hasFreshFix()) {
            _fromLat = ll[0];
            _fromLon = ll[1];
            beginSighting(false);
        } else {
            // No live fix: set the start point by hand, then carry on. Seeded from the
            // last-known position when there is one (every cell stays editable).
            startGridEntry("Your position", gridSeedChars(), self.method(:onManualFrom));
        }
    }

    //! Manual start point chosen (GPS-denied path): adopt it and go sight the bearing.
    public function onManualFrom(ll as Array<Double>) as Void {
        _fromLat = ll[0];
        _fromLon = ll[1];
        beginSighting(true);
    }

    //! Show the compass-sight screen. `replace` swaps the current view (used after the
    //! manual grid screen) instead of stacking another one.
    private function beginSighting(replace as Boolean) as Void {
        var v = new CompassSightView();
        var d = new CompassSightDelegate(self.method(:onCaptured));
        if (replace) {
            WatchUi.switchToView(v, d, WatchUi.SLIDE_LEFT);
        } else {
            WatchUi.pushView(v, d, WatchUi.SLIDE_LEFT);
        }
    }

    //! SET pressed on the sight screen: seed the bearing spinner with the captured
    //! magnetic heading (or 0 when there's no compass) so it can be fine-tuned. The
    //! spinner is in the user's angle unit; when a declination offset is set the value
    //! is your compass (magnetic) reading, which we convert to true before projecting.
    public function onCaptured(magDeg as Double?) as Void {
        var seed = (magDeg != null) ? Settings.bearingFromDegrees(magDeg) : 0;
        var prompt = Settings.hasDeclination() ? "Bearing (MAG)" : "Bearing";
        var az = new NumberInputView(prompt, seed, 0, Settings.bearingMax(), 1, true,
            Settings.bearingSuffix(), Settings.bearingPad(), "NEXT");
        WatchUi.switchToView(az, new NumberInputDelegate(az, self.method(:onAzChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onAzChosen(value as Number) as Void {
        _azMag = Settings.bearingToDegrees(value);   // display unit -> magnetic-frame degrees
        // Range entered in the user's units (metres or yards): step 10, no wrap.
        var unit = Settings.useImperial() ? "yd" : "m";
        var rg = new NumberInputView("Distance", 100, 0, 9999, 10, false, unit, 0, "DONE");
        WatchUi.switchToView(rg, new NumberInputDelegate(rg, self.method(:onRangeChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onRangeChosen(value as Number) as Void {
        // Convert the entered range to metres for the geodesy.
        var rangeM = Settings.useImperial() ? value.toDouble() * 0.9144d : value.toDouble();
        // Project in TRUE north (what the grid math uses); the user may have entered
        // a magnetic bearing, so convert through the declination offset.
        var azTrue = Settings.magToTrue(_azMag);
        var dest = Geo.project(_fromLat, _fromLon, azTrue, rangeM);
        var grid = formatPosition(dest[0], dest[1]);
        // ResultView shows the bearing as entered (magnetic) so it matches the compass.
        var rv = new ResultView(grid, _azMag, rangeM);
        WatchUi.switchToView(rv, new ResultDelegate(rv, dest[0], dest[1]), WatchUi.SLIDE_LEFT);
    }
}

//! "Declination": set the magnetic-vs-true offset for your area, using the same
//! number spinner. East is positive, West negative (the standard convention).
//! Once set, bearings you enter and bearings shown to steer by are magnetic.
class DeclinationFlow {

    public function initialize() {
    }

    public function start() as Void {
        var v = new NumberInputView("Declination (E+)", Settings.declination(),
            Settings.DECL_MIN, Settings.DECL_MAX, 1, false, "°", 0, "SAVE");
        WatchUi.pushView(v, new NumberInputDelegate(v, self.method(:onChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onChosen(value as Number) as Void {
        Settings.setDeclination(value);
        var v = new MessageView("Saved", "Declination " + Settings.declLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! Settings submenu: input mode, coordinates, declination, grid precision and
//! units in one place so the top-level Tools list stays short.
function openSettingsMenu() as Void {
    var items = [
        {"label" => "Input",          "sub" => Settings.inputLabel(), "id" => :input},
        {"label" => "Coordinates",    "sub" => Settings.coordLabel(), "id" => :coord},
        {"label" => "Bearings",       "sub" => Settings.angleLabel(), "id" => :angle},
        {"label" => "Declination",    "sub" => Settings.declLabel(),  "id" => :decl},
        {"label" => "Grid precision", "sub" => Settings.gridLabel(),  "id" => :grid},
        {"label" => "Units",          "sub" => Settings.unitsLabel(), "id" => :units}
    ] as Array<Dictionary>;
    showMenu("Settings", items, new SettingsHandler().method(:onChoose));
}

class SettingsHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        if (id == :input) {
            openInputMenu();
        } else if (id == :coord) {
            openCoordMenu();
        } else if (id == :angle) {
            openAngleMenu();
        } else if (id == :decl) {
            new DeclinationFlow().start();
        } else if (id == :grid) {
            new GridPrecisionFlow().start();
        } else if (id == :units) {
            openUnitsMenu();
        }
    }
}

//! "Input": touch + buttons, or buttons only (which also switches menus to the
//! custom button-driven list).
function openInputMenu() as Void {
    var items = [
        {"label" => "Touch + buttons", "sub" => "default",          "id" => :touch},
        {"label" => "Buttons only",    "sub" => "ignore the screen", "id" => :buttons}
    ] as Array<Dictionary>;
    showMenu("Input", items, new InputHandler().method(:onChoose));
}

class InputHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        Settings.setButtonOnly(id == :buttons);
        var v = new MessageView("Saved", "Input: " + Settings.inputLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Coordinates": show positions as MGRS grids or decimal lat/long.
function openCoordMenu() as Void {
    var items = [
        {"label" => "MGRS",     "sub" => "military grid",   "id" => :mgrs},
        {"label" => "Lat/Long", "sub" => "decimal degrees", "id" => :latlon}
    ] as Array<Dictionary>;
    showMenu("Coordinates", items, new CoordHandler().method(:onChoose));
}

class CoordHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        Settings.setUseLatLon(id == :latlon);
        var v = new MessageView("Saved", "Coordinates: " + Settings.coordLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Bearings": enter and display bearings in degrees (0–359) or NATO mils (0–6399).
function openAngleMenu() as Void {
    var items = [
        {"label" => "Degrees", "sub" => "0–359°",        "id" => :deg},
        {"label" => "Mils",    "sub" => "0–6399 (NATO)", "id" => :mils}
    ] as Array<Dictionary>;
    showMenu("Bearings", items, new AngleHandler().method(:onChoose));
}

class AngleHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        Settings.setUseMils(id == :mils);
        var v = new MessageView("Saved", "Bearings: " + Settings.angleLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Grid precision": choose how many easting/northing figures the MGRS grids show,
//! from 1 (10 km) to 5 (1 m). Reuses the number spinner.
class GridPrecisionFlow {

    public function initialize() {
    }

    public function start() as Void {
        var v = new NumberInputView("Grid digits", Settings.gridDigits(),
            Settings.GRID_MIN, Settings.GRID_MAX, 1, false, "", 0, "SAVE");
        WatchUi.pushView(v, new NumberInputDelegate(v, self.method(:onChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onChosen(value as Number) as Void {
        Settings.setGridDigits(value);
        var v = new MessageView("Saved", "Grid " + Settings.gridLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Units": metric or imperial, applied to every distance the app shows or asks for.
function openUnitsMenu() as Void {
    var items = [
        {"label" => "Metric",   "sub" => "m / km",  "id" => :metric},
        {"label" => "Imperial", "sub" => "yd / mi", "id" => :imperial}
    ] as Array<Dictionary>;
    showMenu("Units", items, new UnitsHandler().method(:onChoose));
}

class UnitsHandler {

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        Settings.setUseImperial(id == :imperial);
        var v = new MessageView("Saved", Settings.unitsLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Mark this spot": open a live screen that holds GPS and shows the current
//! position, so the saved mark is where you are *now* - not a fix left frozen at
//! the spot where the menu was opened. The screen waits for a fix and owns SAVE.
function startMarkFlow() as Void {
    var v = new MarkView();
    WatchUi.pushView(v, new MarkDelegate(v), WatchUi.SLIDE_LEFT);
}

//! Present the preset-name menu that saves the given coordinates as a mark. Shared
//! by "Mark this spot" (current position) and "save target" on the result screen.
function showMarkNameMenu(lat as Double, lon as Double) as Void {
    var items = [] as Array<Dictionary>;
    for (var i = 0; i < Marks.PRESETS.size(); i++) {
        var name = Marks.PRESETS[i];
        items.add({"label" => name, "sub" => null, "id" => name});
    }
    showMenu("Mark as…", items, new MarkNameHandler(lat, lon).method(:onChoose));
}

class MarkNameHandler {

    private var _lat as Double;
    private var _lon as Double;

    public function initialize(lat as Double, lon as Double) {
        _lat = lat;
        _lon = lon;
    }

    public function onChoose(id as Object) as Void {
        var name = id as String;
        Marks.save(name, _lat, _lon);
        var v = new MessageView("Saved", name + " marked here");
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Take me back": list saved marks (with live distance), pick one to navigate to.
function startTakeMeBack() as Void {
    var list = Marks.all();
    if (list.size() == 0) {
        var v = new MessageView("No marks yet", "Use 'Mark this spot'\nfirst.");
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return;
    }
    var ll = currentLatLon();
    var items = [] as Array<Dictionary>;
    for (var i = 0; i < list.size(); i++) {
        var m = list[i];
        var name = m["n"] as String;
        var sub = "saved";
        if (ll != null) {
            var inv = Geo.inverse(ll[0], ll[1], m["la"].toDouble(), m["lo"].toDouble());
            sub = formatDistance(inv[0]) + " away";
        }
        items.add({"label" => name, "sub" => sub, "id" => name});
    }
    showMenu("Take me back", items, new TakeMeBackHandler(list).method(:onChoose));
}

class TakeMeBackHandler {

    private var _list as Array<Dictionary>;

    public function initialize(list as Array<Dictionary>) {
        _list = list;
    }

    public function onChoose(id as Object) as Void {
        var name = id as String;
        for (var i = 0; i < _list.size(); i++) {
            var m = _list[i];
            if ((m["n"] as String).equals(name)) {
                var v = new ReturnNavView(name, m["la"].toDouble(), m["lo"].toDouble());
                WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
                return;
            }
        }
    }
}

//! "Manage marks": list saved marks; selecting one confirms deletion.
function startManageMarks() as Void {
    var list = Marks.all();
    if (list.size() == 0) {
        var v = new MessageView("No marks yet", "Nothing to manage.");
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return;
    }
    var items = [] as Array<Dictionary>;
    for (var i = 0; i < list.size(); i++) {
        var m = list[i];
        var name = m["n"] as String;
        // Show the mark's coordinates so two similarly-named marks can be told apart.
        var grid = formatPosition(m["la"].toDouble(), m["lo"].toDouble());
        items.add({"label" => name, "sub" => grid, "id" => name});
    }
    showMenu("Manage marks", items, new ManageHandler().method(:onChoose));
}

class ManageHandler {

    private var _pendingName as String = "";

    public function initialize() {
    }

    public function onChoose(id as Object) as Void {
        _pendingName = id as String;
        var cv = new ConfirmView("Delete " + _pendingName + "?");
        WatchUi.pushView(cv, new ConfirmDelegate(self.method(:confirmDelete)), WatchUi.SLIDE_IMMEDIATE);
    }

    //! Delete from storage, then close the confirm and the menu (returning to Tools);
    //! the list is rebuilt fresh next time Manage is opened. Returning true tells the
    //! ConfirmDelegate to also pop the underlying menu.
    public function confirmDelete() as Boolean {
        Marks.remove(_pendingName);
        return true;
    }
}

//! Custom yes/no screen. Unlike the native dialog, it labels the buttons:
//! START = confirm (upper-right), BACK = cancel (lower-right).
class ConfirmView extends WatchUi.View {

    private var _prompt as String;

    public function initialize(prompt as String) {
        View.initialize();
        _prompt = prompt;
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, _prompt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawButtonHint(dc, 0.32, true, "CONFIRM", Graphics.COLOR_WHITE, false);
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
    }
}

//! START runs the confirm action then closes; BACK cancels (default pop).
class ConfirmDelegate extends ButtonNavDelegate {

    private var _onYes as Lang.Method;

    public function initialize(onYes as Lang.Method) {
        ButtonNavDelegate.initialize();
        _onYes = onYes;
    }

    public function onSelect() as Boolean {
        // The action may return true to ask that the underlying view close too.
        var closeParent = _onYes.invoke();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (closeParent == true) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}

//! Centered message screen. Title in yellow, body in small white text.
class MessageView extends WatchUi.View {

    private var _title as String;
    private var _body as String;

    public function initialize(title as String, body as String) {
        View.initialize();
        _title = title;
        _body = body;
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - dc.getFontHeight(Graphics.FONT_SMALL) * 2, Graphics.FONT_SMALL,
            _title, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - dc.getFontHeight(Graphics.FONT_SMALL), Graphics.FONT_XTINY, _body,
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
