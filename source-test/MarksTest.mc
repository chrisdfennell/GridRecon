import Toybox.Lang;
import Toybox.Test;
import Toybox.Application;
import Toybox.Application.Storage;

//! Tests for the persistent marks store, focused on the robustness this layer is
//! supposed to provide: round-tripping, overwrite-by-name, transparent migration
//! from the v1.0.0 bare-array format, and graceful handling of corrupt/foreign
//! values. Each test saves and restores the live "marks" key.

function clearMarks() as Void {
    Storage.deleteValue(Marks.KEY);
}

//! Put back whatever was in the store before a test ran (or clear it if empty).
function restoreMarks(saved as Application.PropertyValueType?) as Void {
    if (saved == null) {
        Storage.deleteValue(Marks.KEY);
    } else {
        Storage.setValue(Marks.KEY, saved);
    }
}

(:test)
function testMarksRoundTrip(logger as Test.Logger) as Boolean {
    var saved = Storage.getValue(Marks.KEY);
    clearMarks();

    Test.assertMessage(Marks.all().size() == 0, "starts empty");
    Marks.save("Car", 45.0d, -93.0d);
    var list = Marks.all();
    Test.assertMessage(list.size() == 1, "one after save");
    Test.assertMessage((list[0]["n"] as String).equals("Car"), "name");
    Test.assertMessage(nearD(list[0]["la"].toDouble(), 45.0d, 1.0e-9d), "lat");
    Test.assertMessage(nearD(list[0]["lo"].toDouble(), -93.0d, 1.0e-9d), "lon");

    Marks.remove("Car");
    Test.assertMessage(Marks.all().size() == 0, "empty after remove");

    restoreMarks(saved);
    return true;
}

(:test)
function testMarksOverwriteByName(logger as Test.Logger) as Boolean {
    var saved = Storage.getValue(Marks.KEY);
    clearMarks();

    Marks.save("Car", 1.0d, 2.0d);
    Marks.save("Car", 3.0d, 4.0d);     // same name -> overwrite, not append
    var list = Marks.all();
    Test.assertMessage(list.size() == 1, "still one");
    Test.assertMessage(nearD(list[0]["la"].toDouble(), 3.0d, 1.0e-9d), "updated lat");

    restoreMarks(saved);
    return true;
}

(:test)
function testMarksLegacyMigration(logger as Test.Logger) as Boolean {
    var saved = Storage.getValue(Marks.KEY);

    // Simulate a v1.0.0 install: a bare array with no version wrapper.
    var legacy = [ { "n" => "Old", "la" => 10.0d, "lo" => 20.0d } ] as Array<Dictionary>;
    Storage.setValue(Marks.KEY, legacy);
    var list = Marks.all();
    Test.assertMessage(list.size() == 1 && (list[0]["n"] as String).equals("Old"), "reads legacy array");

    // Any write migrates the store to the versioned wrapper.
    Marks.save("New", 30.0d, 40.0d);
    var raw = Storage.getValue(Marks.KEY);
    Test.assertMessage(raw instanceof Lang.Dictionary, "migrated to wrapper");
    var wrap = raw as Dictionary;
    Test.assertMessage(wrap["v"] == Marks.VERSION, "version stamped");
    Test.assertMessage(Marks.all().size() == 2, "both marks present");

    restoreMarks(saved);
    return true;
}

(:test)
function testMarksCorruptValue(logger as Test.Logger) as Boolean {
    var saved = Storage.getValue(Marks.KEY);

    Storage.setValue(Marks.KEY, "not a marks list");
    Test.assertMessage(Marks.all().size() == 0, "string value -> empty");

    Storage.setValue(Marks.KEY, 42);
    Test.assertMessage(Marks.all().size() == 0, "number value -> empty");

    restoreMarks(saved);
    return true;
}

(:test)
function testMarksFiltersInvalidEntries(logger as Test.Logger) as Boolean {
    var saved = Storage.getValue(Marks.KEY);

    // One good entry, plus garbage that must be dropped rather than crash callers.
    var entries = [
        { "n" => "Good", "la" => 1.0d, "lo" => 2.0d },
        { "n" => "NoCoords" },
        { "la" => 5.0d, "lo" => 6.0d }
    ] as Array<Dictionary>;
    Storage.setValue(Marks.KEY, { "v" => Marks.VERSION, "m" => entries });
    var list = Marks.all();
    Test.assertMessage(list.size() == 1, "only valid entry kept, got " + list.size());
    Test.assertMessage((list[0]["n"] as String).equals("Good"), "kept the good one");

    restoreMarks(saved);
    return true;
}
