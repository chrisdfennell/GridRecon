import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Build and show the tools menu. Called from the home screen.
function openToolMenu() as Void {
    var menu = new WatchUi.Menu2({:title => "Tools"});
    menu.addItem(new WatchUi.MenuItem("Mark this spot", "save where you are", :mark, null));
    menu.addItem(new WatchUi.MenuItem("Take me back", "navigate to a mark", :back, null));
    menu.addItem(new WatchUi.MenuItem("Manage marks", "delete a mark", :manage, null));
    menu.addItem(new WatchUi.MenuItem("Find a target", "where is that thing?", :target, null));
    menu.addItem(new WatchUi.MenuItem("Go to a grid", "navigate to an MGRS grid", :gogrid, null));
    menu.addItem(new WatchUi.MenuItem("Settings", "declination · grid · units", :settings, null));
    menu.addItem(new WatchUi.MenuItem("Help", "how this works", :help, null));
    menu.addItem(new WatchUi.MenuItem("About", null, :about, null));
    WatchUi.pushView(menu, new ToolMenuDelegate(), WatchUi.SLIDE_LEFT);
}

class ToolMenuDelegate extends WatchUi.Menu2InputDelegate {

    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :target) {
            var flow = new TargetLocationFlow();
            flow.start();
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
            var v = new MessageView("GridRecon  v1.1.0",
                "Land navigation when\nGPS is off or jammed.\nMore tools coming.");
            WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

//! "Find a target": take the current fix, ask for the compass bearing and the
//! distance to a target, then compute and show the target's map grid.
class TargetLocationFlow {

    private var _fromLat as Double = 0.0d;
    private var _fromLon as Double = 0.0d;
    private var _azMag as Double = 0.0d;    // bearing as entered (magnetic if declination set)

    public function initialize() {
    }

    public function start() as Void {
        var ll = currentLatLon();
        if (ll == null || !hasFreshFix()) {
            var v = new MessageView("No fresh GPS",
                "Wait for a solid fix,\nthen try again.");
            WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        _fromLat = ll[0];
        _fromLon = ll[1];

        // Azimuth: 0..359, wraps, zero-padded to 3 digits, degree suffix. When a
        // declination offset is set, the value you enter is your compass (magnetic)
        // reading - we convert to true before projecting.
        var prompt = Settings.hasDeclination() ? "Bearing (MAG)" : "Bearing";
        var az = new NumberInputView(prompt, 0, 0, 359, 1, true, "°", 3, "NEXT");
        WatchUi.pushView(az, new NumberInputDelegate(az, self.method(:onAzChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onAzChosen(value as Number) as Void {
        _azMag = value.toDouble();
        // Range entered in the user's units (metres or yards): step 10, no wrap.
        var suffix = Settings.useImperial() ? " yd" : " m";
        var rg = new NumberInputView("Distance", 100, 0, 9999, 10, false, suffix, 0, "DONE");
        WatchUi.switchToView(rg, new NumberInputDelegate(rg, self.method(:onRangeChosen)), WatchUi.SLIDE_LEFT);
    }

    public function onRangeChosen(value as Number) as Void {
        // Convert the entered range to metres for the geodesy.
        var rangeM = Settings.useImperial() ? value.toDouble() * 0.9144d : value.toDouble();
        // Project in TRUE north (what the grid math uses); the user may have entered
        // a magnetic bearing, so convert through the declination offset.
        var azTrue = Settings.magToTrue(_azMag);
        var dest = Geo.project(_fromLat, _fromLon, azTrue, rangeM);
        var grid = Geo.mgrsAtPrecision(dest[0], dest[1], Settings.gridDigits());
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

//! Settings submenu: declination, grid precision and units in one place so the
//! top-level Tools list stays short.
function openSettingsMenu() as Void {
    var menu = new WatchUi.Menu2({:title => "Settings"});
    menu.addItem(new WatchUi.MenuItem("Declination", Settings.declLabel(), :decl, null));
    menu.addItem(new WatchUi.MenuItem("Grid precision", Settings.gridLabel(), :grid, null));
    menu.addItem(new WatchUi.MenuItem("Units", Settings.unitsLabel(), :units, null));
    WatchUi.pushView(menu, new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT);
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :decl) {
            new DeclinationFlow().start();
        } else if (id == :grid) {
            new GridPrecisionFlow().start();
        } else if (id == :units) {
            openUnitsMenu();
        }
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
    var menu = new WatchUi.Menu2({:title => "Units"});
    menu.addItem(new WatchUi.MenuItem("Metric", "m / km", :metric, null));
    menu.addItem(new WatchUi.MenuItem("Imperial", "yd / mi", :imperial, null));
    WatchUi.pushView(menu, new UnitsMenuDelegate(), WatchUi.SLIDE_LEFT);
}

class UnitsMenuDelegate extends WatchUi.Menu2InputDelegate {

    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        Settings.setUseImperial(item.getId() == :imperial);
        var v = new MessageView("Saved", Settings.unitsLabel());
        WatchUi.switchToView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
    }
}

//! "Mark this spot": confirm a fresh fix, then pick a name to save it under.
function startMarkFlow() as Void {
    var ll = currentLatLon();
    if (ll == null || !hasFreshFix()) {
        var v = new MessageView("No fresh GPS", "Wait for a solid fix,\nthen mark.");
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return;
    }
    showMarkNameMenu(ll[0], ll[1]);
}

//! Present the preset-name menu that saves the given coordinates as a mark. Shared
//! by "Mark this spot" (current position) and "save target" on the result screen.
function showMarkNameMenu(lat as Double, lon as Double) as Void {
    var menu = new WatchUi.Menu2({:title => "Mark as…"});
    for (var i = 0; i < Marks.PRESETS.size(); i++) {
        var name = Marks.PRESETS[i];
        menu.addItem(new WatchUi.MenuItem(name, null, name, null));
    }
    WatchUi.pushView(menu, new MarkNameDelegate(lat, lon), WatchUi.SLIDE_LEFT);
}

class MarkNameDelegate extends WatchUi.Menu2InputDelegate {

    private var _lat as Double;
    private var _lon as Double;

    public function initialize(lat as Double, lon as Double) {
        Menu2InputDelegate.initialize();
        _lat = lat;
        _lon = lon;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var name = item.getId() as String;
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
    var menu = new WatchUi.Menu2({:title => "Take me back"});
    for (var i = 0; i < list.size(); i++) {
        var m = list[i];
        var name = m["n"] as String;
        var sub = "saved";
        if (ll != null) {
            var inv = Geo.inverse(ll[0], ll[1], m["la"].toDouble(), m["lo"].toDouble());
            sub = formatDistance(inv[0]) + " away";
        }
        menu.addItem(new WatchUi.MenuItem(name, sub, name, null));
    }
    WatchUi.pushView(menu, new TakeMeBackDelegate(list), WatchUi.SLIDE_LEFT);
}

class TakeMeBackDelegate extends WatchUi.Menu2InputDelegate {

    private var _list as Array<Dictionary>;

    public function initialize(list as Array<Dictionary>) {
        Menu2InputDelegate.initialize();
        _list = list;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var name = item.getId() as String;
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
    var menu = new WatchUi.Menu2({:title => "Manage marks"});
    for (var i = 0; i < list.size(); i++) {
        var m = list[i];
        var name = m["n"] as String;
        // Show the mark's grid so two similarly-named marks can be told apart.
        var grid = Geo.mgrsAtPrecision(m["la"].toDouble(), m["lo"].toDouble(), Settings.gridDigits());
        menu.addItem(new WatchUi.MenuItem(name, grid, name, null));
    }
    WatchUi.pushView(menu, new ManageMarksDelegate(menu), WatchUi.SLIDE_LEFT);
}

class ManageMarksDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;
    private var _pendingName as String = "";

    public function initialize(menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        _pendingName = item.getId() as String;
        var cv = new ConfirmView("Delete " + _pendingName + "?");
        WatchUi.pushView(cv, new ConfirmDelegate(self.method(:confirmDelete)), WatchUi.SLIDE_IMMEDIATE);
    }

    //! Delete from storage AND from the live menu (so the list refreshes in place).
    //! Returns true if the list is now empty, signalling the caller to close it.
    public function confirmDelete() as Boolean {
        Marks.remove(_pendingName);
        var idx = _menu.findItemById(_pendingName);
        if (idx >= 0) {
            _menu.deleteItem(idx);
        }
        return Marks.all().size() == 0;
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
class ConfirmDelegate extends WatchUi.BehaviorDelegate {

    private var _onYes as Lang.Method;

    public function initialize(onYes as Lang.Method) {
        BehaviorDelegate.initialize();
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
