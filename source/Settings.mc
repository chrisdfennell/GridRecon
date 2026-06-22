import Toybox.Lang;
import Toybox.Application.Storage;

//! User settings, persisted across runs.
//!
//! Magnetic declination lets you enter the bearing your baseplate compass actually
//! reads (magnetic) instead of doing the true-north conversion in your head.
//! GridRecon works internally in TRUE north (that's what MGRS/maps use); the stored
//! offset bridges the two.
//!
//! Convention (the usual one): declination is positive EAST.
//!   true = magnetic + declination       (E is +, W is -)
//! e.g. with 13° E declination, a compass reading of 045° is 058° true.
//!
//! It's a single value set once for your area - declination changes slowly across a
//! region, so a hand-set offset is as good as the compass reading it corrects.
module Settings {

    const DECL_KEY = "declination";   // signed degrees, East positive
    const DECL_MIN = -30;             // covers inhabited land; poles excluded anyway
    const DECL_MAX = 30;

    const GRID_KEY = "gridDigits";    // MGRS easting/northing digits shown (1..5)
    const GRID_MIN = 1;               // 10 km
    const GRID_MAX = 5;               // 1 m
    const GRID_DEFAULT = 5;

    const UNITS_KEY = "imperial";     // 0 = metric (default), 1 = imperial

    const COORD_KEY = "coordFmt";     // 0 = MGRS (default), 1 = lat/long

    const INPUT_KEY = "buttonOnly";   // 0 = touch + buttons (default), 1 = buttons only

    //! Stored declination in degrees (East +). 0 if never set.
    function declination() as Number {
        var v = Storage.getValue(DECL_KEY);
        if (v == null) {
            return 0;
        }
        return v as Number;
    }

    function setDeclination(deg as Number) as Void {
        Storage.setValue(DECL_KEY, deg);
    }

    //! True if a non-zero offset is in effect (i.e. entered/shown bearings are magnetic).
    function hasDeclination() as Boolean {
        return declination() != 0;
    }

    //! Magnetic bearing -> true bearing (what the projection/grid math needs).
    function magToTrue(magDeg as Double) as Double {
        return norm360(magDeg + declination().toDouble());
    }

    //! True bearing -> magnetic bearing (what to dial on a compass in the field).
    function trueToMag(trueDeg as Double) as Double {
        return norm360(trueDeg - declination().toDouble());
    }

    //! Human label for menus/confirmations, e.g. "13° E", "6° W", "off (true north)".
    function declLabel() as String {
        var d = declination();
        if (d == 0) {
            return "off (true north)";
        } else if (d > 0) {
            return d.format("%d") + "° E";
        }
        return (-d).format("%d") + "° W";
    }

    //! --- grid precision --------------------------------------------------------

    //! MGRS easting/northing digits to display (1..5). 5 = 1 m, the default.
    function gridDigits() as Number {
        var v = Storage.getValue(GRID_KEY);
        if (v == null) {
            return GRID_DEFAULT;
        }
        var n = v as Number;
        if (n < GRID_MIN) { n = GRID_MIN; }
        if (n > GRID_MAX) { n = GRID_MAX; }
        return n;
    }

    function setGridDigits(n as Number) as Void {
        Storage.setValue(GRID_KEY, n);
    }

    //! Menu label pairing the digit count with the ground resolution, e.g. "5 (1 m)".
    function gridLabel() as String {
        var res = ["10 km", "1 km", "100 m", "10 m", "1 m"];   // index = digits - 1
        var d = gridDigits();
        return d.format("%d") + " (" + res[d - 1] + ")";
    }

    //! --- units -----------------------------------------------------------------

    function useImperial() as Boolean {
        return Storage.getValue(UNITS_KEY) == 1;
    }

    function setUseImperial(imperial as Boolean) as Void {
        Storage.setValue(UNITS_KEY, imperial ? 1 : 0);
    }

    function unitsLabel() as String {
        return useImperial() ? "Imperial (yd/mi)" : "Metric (m/km)";
    }

    //! --- coordinate format -----------------------------------------------------

    function useLatLon() as Boolean {
        return Storage.getValue(COORD_KEY) == 1;
    }

    function setUseLatLon(latlon as Boolean) as Void {
        Storage.setValue(COORD_KEY, latlon ? 1 : 0);
    }

    function coordLabel() as String {
        return useLatLon() ? "Lat/Long" : "MGRS";
    }

    //! --- input mode ------------------------------------------------------------

    //! True if the user wants buttons only (touch ignored, custom button menus).
    function buttonOnly() as Boolean {
        return Storage.getValue(INPUT_KEY) == 1;
    }

    function setButtonOnly(on as Boolean) as Void {
        Storage.setValue(INPUT_KEY, on ? 1 : 0);
    }

    function inputLabel() as String {
        return buttonOnly() ? "Buttons only" : "Touch + buttons";
    }
}
