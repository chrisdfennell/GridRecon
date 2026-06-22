import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Go to a grid": punch in an MGRS grid you've been given and navigate to it -
//! the inverse of "Find a target". Entry is seeded from your current position, so
//! the whole grid is pre-filled and the cursor starts on the easting; you usually
//! just dial the digits that differ and press GO. If the target is in a different
//! square (or zone), press BACK to step left into the zone / band / square cells -
//! every character is editable.
//!
//!   UP / DOWN  change the highlighted character    START  next cell (GO on the last)
//!   BACK       previous cell (exits at the first)
//!
//! The 15 cells, in display order "ZZB SQ EEEEE NNNNN":
//!   0,1 zone digits   2 band letter   3 column letter   4 row letter
//!   5..9 easting       10..14 northing
class GridEntryView extends WatchUi.View {

    private const BANDS = "CDEFGHJKLMNPQRSTUVWX";   // latitude bands (I, O omitted)
    private const ROWS  = "ABCDEFGHJKLMNPQRSTUV";   // 100 km row letters
    private const DIGITS = "0123456789";

    private var _chars as Array<String>;   // 15 single-character cells
    private var _cursor as Number = 5;     // start on the first easting digit
    private var _hints as HintTimer = new HintTimer();

    public function initialize(chars as Array<String>) {
        View.initialize();
        _chars = chars;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    public function atLast() as Boolean {
        return _cursor >= 14;
    }

    //! Move the cursor; returns false if it can't (already at the requested edge).
    public function moveCursor(delta as Number) as Boolean {
        var n = _cursor + delta;
        if (n < 0 || n > 14) {
            return false;
        }
        _cursor = n;
        _hints.reset();
        return true;
    }

    //! Step the highlighted character through its allowed set (wraps).
    public function adjustChar(delta as Number) as Void {
        var alpha = alphabetFor(_cursor);
        var idx = alpha.find(_chars[_cursor]);
        if (idx == null) { idx = 0; }
        idx = ((idx + delta) % alpha.length() + alpha.length()) % alpha.length();
        _chars[_cursor] = alpha.substring(idx, idx + 1);
        _hints.reset();
    }

    //! Full MGRS string, e.g. "18T WL 80740 04691".
    public function grid() as String {
        var zb = _chars[0] + _chars[1] + _chars[2];
        var sq = _chars[3] + _chars[4];
        var e = "";
        var n = "";
        for (var i = 5; i < 10; i++)  { e += _chars[i]; }
        for (var i = 10; i < 15; i++) { n += _chars[i]; }
        return zb + " " + sq + " " + e + " " + n;
    }

    //! Allowed character cycle for a cell.
    private function alphabetFor(i as Number) as String {
        if (i == 2) { return BANDS; }
        if (i == 4) { return ROWS; }
        if (i == 3) {
            // Column letters cycle in sets of 8 every 3 zones (I, O omitted).
            var zone = (_chars[0] + _chars[1]).toNumber();
            if (zone == null) { zone = 1; }
            var set = zone % 3;
            return (set == 1) ? "ABCDEFGH" : ((set == 2) ? "JKLMNPQR" : "STUVWXYZ");
        }
        return DIGITS;   // zone digits (0,1) and easting/northing (5..14)
    }

    private function label() as String {
        if (_cursor < 2)  { return "zone"; }
        if (_cursor == 2) { return "band"; }
        if (_cursor == 3) { return "column"; }
        if (_cursor == 4) { return "row"; }
        if (_cursor < 10) { return "easting"; }
        return "northing";
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (dc.getHeight() * 0.20).toNumber(), Graphics.FONT_TINY, "Enter grid", vc);

        // Display slots: cell index per glyph, -1 for the group-separating spaces.
        var slots = [0, 1, 2, -1, 3, 4, -1, 5, 6, 7, 8, 9, -1, 10, 11, 12, 13, 14] as Array<Number>;

        // Build the rendered string and pick the largest font that fits.
        var shown = "";
        for (var s = 0; s < slots.size(); s++) {
            shown += (slots[s] < 0) ? " " : _chars[slots[s]];
        }
        var maxW = (w * 0.92).toNumber();
        var font = Graphics.FONT_XTINY;
        for (var i = 0; i < FIT_FONTS.size(); i++) {
            if (dc.getTextWidthInPixels(shown, FIT_FONTS[i]) <= maxW) {
                font = FIT_FONTS[i];
                break;
            }
        }

        // Lay the glyphs out left-to-right, centered, highlighting the active cell.
        var total = dc.getTextWidthInPixels(shown, font);
        var x = cx - total / 2;
        var fh = dc.getFontHeight(font);
        for (var s = 0; s < slots.size(); s++) {
            var ch = (slots[s] < 0) ? " " : _chars[slots[s]];
            var cw = dc.getTextWidthInPixels(ch, font);
            var active = (slots[s] == _cursor);
            var color = Graphics.COLOR_WHITE;
            if (active) {
                color = Graphics.COLOR_YELLOW;
            } else if (slots[s] >= 0 && slots[s] < 5) {
                color = Graphics.COLOR_LT_GRAY;   // the seeded zone/band/square prefix
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + cw / 2, cy, font, ch, vc);
            if (active) {
                dc.fillRectangle(x + 1, cy + fh / 2 - 2, cw - 2, 2);
            }
            x += cw;
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + fh, Graphics.FONT_XTINY, label(), vc);

        drawButtonHint(dc, 0.47, false, "+", Graphics.COLOR_WHITE, true);                  // UP
        drawButtonHint(dc, 0.67, false, "-", Graphics.COLOR_WHITE, true);                  // DOWN
        drawButtonHint(dc, 0.32, true, atLast() ? "GO" : "NEXT", Graphics.COLOR_WHITE, true);
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);             // always-on
    }
}

//! Drives GridEntryView: UP/DOWN change the character, START advances (and on the
//! last cell computes the lat/lon and starts navigation), BACK steps left or cancels.
class GridEntryDelegate extends ButtonNavDelegate {

    private var _view as GridEntryView;

    public function initialize(view as GridEntryView) {
        ButtonNavDelegate.initialize();
        _view = view;
    }

    public function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP) {
            _view.adjustChar(1);
            WatchUi.requestUpdate();
            return true;
        } else if (k == WatchUi.KEY_DOWN) {
            _view.adjustChar(-1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    public function onSelect() as Boolean {
        if (!_view.atLast()) {
            _view.moveCursor(1);
            WatchUi.requestUpdate();
            return true;
        }
        var ll = Geo.mgrsToLatLon(_view.grid());
        if (ll == null) {
            var m = new MessageView("Bad grid", "Check the zone, square\nand digits, then retry.");
            WatchUi.pushView(m, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        }
        var nav = new ReturnNavView("Grid", ll[0], ll[1]);
        WatchUi.switchToView(nav, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! BACK steps the cursor left; at the first cell it falls through to cancel.
    public function onBack() as Boolean {
        if (_view.moveCursor(-1)) {
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}

//! Build and show the grid-entry screen, seeded from the current position.
function startGoToGrid() as Void {
    var ll = currentLatLon();
    if (ll == null) {
        var v = new MessageView("No GPS yet", "Need a fix first to\nseed the grid square.");
        WatchUi.pushView(v, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return;
    }
    // Seed every cell from where we are; the user edits only what differs.
    var parts = splitOnSpace(Geo.latLonToMgrs(ll[0], ll[1]));   // [ZZB, SQ, EEEEE, NNNNN]
    var zb = parts[0];
    var sq = parts[1];
    var e = parts[2];
    var n = parts[3];
    var chars = [
        zb.substring(0, 1), zb.substring(1, 2), zb.substring(2, 3),
        sq.substring(0, 1), sq.substring(1, 2)
    ] as Array<String>;
    for (var i = 0; i < 5; i++) { chars.add(e.substring(i, i + 1)); }
    for (var i = 0; i < 5; i++) { chars.add(n.substring(i, i + 1)); }

    var v = new GridEntryView(chars);
    WatchUi.pushView(v, new GridEntryDelegate(v), WatchUi.SLIDE_LEFT);
}
