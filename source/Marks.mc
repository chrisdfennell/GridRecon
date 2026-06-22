import Toybox.Lang;
import Toybox.Application.Storage;

//! Saved marks ("Car", "Camp", ...), persisted so they survive the app closing -
//! that persistence is what makes "where'd I park?" work hours later.
//!
//! On-disk format is a versioned wrapper so the layout can evolve without
//! orphaning existing data:
//!   { "v" => 1, "m" => [ { "n" => name, "la" => latDeg, "lo" => lonDeg }, ... ] }
//!
//! v1.0.0 stored the bare array (no wrapper). all() still reads that legacy form,
//! and the next save() rewrites it wrapped - so upgrades migrate transparently and
//! a corrupted/foreign value degrades to "no marks" instead of crashing.
module Marks {

    const KEY = "marks";
    const VERSION = 1;

    //! Safety cap. The preset names overwrite in place, so this is only a backstop
    //! against unbounded growth (e.g. future free-form naming).
    const MAX = 50;

    //! Preset labels - picking a name on a button watch beats typing one.
    //! Re-marking an existing name overwrites it (your car moved).
    const PRESETS = ["Car", "Camp", "Trailhead", "Stand", "Cache", "Water", "Mark A", "Mark B"];

    //! All saved marks (possibly empty). Tolerates null, the legacy bare-array
    //! format, and corrupt values; only well-formed entries are returned.
    function all() as Array<Dictionary> {
        var raw = Storage.getValue(KEY);
        if (raw == null) {
            return [] as Array<Dictionary>;
        }

        var list;
        if (raw instanceof Lang.Dictionary) {
            // Versioned wrapper. (Future migrations would branch on raw["v"] here.)
            list = raw["m"];
        } else if (raw instanceof Lang.Array) {
            list = raw;            // legacy v1.0.0 bare array
        } else {
            return [] as Array<Dictionary>;   // foreign/corrupt value
        }
        if (!(list instanceof Lang.Array)) {
            return [] as Array<Dictionary>;
        }

        // Keep only structurally valid entries.
        var out = [] as Array<Dictionary>;
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            if (isValidEntry(e)) {
                out.add(e as Dictionary);
            }
        }
        return out;
    }

    //! Save (or overwrite) a mark by name. New marks beyond MAX are ignored.
    function save(name as String, lat as Double, lon as Double) as Void {
        var list = all();
        var entry = { "n" => name, "la" => lat, "lo" => lon };
        for (var i = 0; i < list.size(); i++) {
            if ((list[i]["n"] as String).equals(name)) {
                list[i] = entry;
                persist(list);
                return;
            }
        }
        if (list.size() >= MAX) {
            return;
        }
        list.add(entry);
        persist(list);
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
        persist(out);
    }

    //! --- internals -------------------------------------------------------------

    //! Write the list back in the current versioned wrapper (migrates legacy data).
    function persist(list as Array<Dictionary>) as Void {
        Storage.setValue(KEY, { "v" => VERSION, "m" => list });
    }

    //! An entry is usable iff it has a String name and non-null coordinates.
    function isValidEntry(e as Object?) as Boolean {
        if (!(e instanceof Lang.Dictionary)) {
            return false;
        }
        return (e["n"] instanceof Lang.String) && e["la"] != null && e["lo"] != null;
    }
}
