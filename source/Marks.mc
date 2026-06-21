import Toybox.Lang;
import Toybox.Application.Storage;

//! Saved marks ("Car", "Camp", ...), persisted so they survive the app closing -
//! that persistence is what makes "where'd I park?" work hours later.
//!
//! Stored under one Storage key as an array of dictionaries:
//!   [ { "n" => name, "la" => latDeg, "lo" => lonDeg }, ... ]
module Marks {

    const KEY = "marks";

    //! Preset labels - picking a name on a button watch beats typing one.
    //! Re-marking an existing name overwrites it (your car moved).
    const PRESETS = ["Car", "Camp", "Trailhead", "Stand", "Cache", "Water", "Mark A", "Mark B"];

    //! All saved marks (possibly empty).
    function all() as Array<Dictionary> {
        var v = Storage.getValue(KEY);
        if (v == null) {
            return [] as Array<Dictionary>;
        }
        return v as Array<Dictionary>;
    }

    //! Save (or overwrite) a mark by name.
    function save(name as String, lat as Double, lon as Double) as Void {
        var list = all();
        var entry = { "n" => name, "la" => lat, "lo" => lon };
        for (var i = 0; i < list.size(); i++) {
            if ((list[i]["n"] as String).equals(name)) {
                list[i] = entry;
                Storage.setValue(KEY, list);
                return;
            }
        }
        list.add(entry);
        Storage.setValue(KEY, list);
    }

    //! Remove a mark by name (no-op if it doesn't exist).
    function remove(name as String) as Void {
        var list = all();
        var out = [] as Array<Dictionary>;
        for (var i = 0; i < list.size(); i++) {
            if (!((list[i]["n"] as String).equals(name))) {
                out.add(list[i]);
            }
        }
        Storage.setValue(KEY, out);
    }
}
