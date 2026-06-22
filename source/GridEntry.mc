import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! "Go to a grid": punch in an MGRS grid you've been given and navigate to it -
//! the inverse of "Find a target". Entry is seeded from your current position, so
//! the zone/band/100 km-square prefix is pre-filled (you and the target are almost
//! always in the same square) and you only dial the 10 easting/northing digits.
//!
//!   UP / DOWN  change the highlighted digit      START  next digit (GO on the last)
//!   BACK       previous digit (exits at the first)
class GridEntryView extends WatchUi.View {

    private var _prefix as String;        // "18T WL"
    private var _digits as Array<Number>; // 10 digits: 5 easting + 5 northing
    private var _cursor as Number = 0;
    private var _hints as HintTimer = new HintTimer();

    public function initialize(prefix as String, digits as Array<Number>) {
        View.initialize();
        _prefix = prefix;
        _digits = digits;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    public function cursor() as Number {
        return _cursor;
    }

    public function atLast() as Boolean {
        return _cursor >= 9;
    }

    public function bumpHints() as Void {
        _hints.reset();
    }

    //! Move the cursor; returns false if it can't (already at the requested edge).
    public function moveCursor(delta as Number) as Boolean {
        var n = _cursor + delta;
        if (n < 0 || n > 9) {
            return false;
        }
        _cursor = n;
        _hints.reset();
        return true;
    }

    //! Step the highlighted digit (wraps 0..9).
    public function adjustDigit(delta as Number) as Void {
        _digits[_cursor] = ((_digits[_cursor] + delta) % 10 + 10) % 10;
        _hints.reset();
    }

    //! Full MGRS string, e.g. "18T WL 80740 04691".
    public function grid() as String {
        var e = "";
        var n = "";
        for (var i = 0; i < 5; i++) { e += _digits[i].format("%d"); }
        for (var i = 5; i < 10; i++) { n += _digits[i].format("%d"); }
        return _prefix + " " + e + " " + n;
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Prefix (the fixed zone/band/square) above the editable digits.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (dc.getHeight() * 0.20).toNumber(), Graphics.FONT_TINY, _prefix, vc);

        // Largest digit font whose 10-digit row (plus a gap) fits the width.
        var maxW = (w * 0.9).toNumber();
        var font = Graphics.FONT_XTINY;
        var dw = 0;
        for (var i = 0; i < FIT_FONTS.size(); i++) {
            var f = FIT_FONTS[i];
            var cw = dc.getTextWidthInPixels("0", f);
            if (cw * 11 <= maxW) {   // 10 digits + one digit-width gap between groups
                font = f;
                dw = cw;
                break;
            }
        }
        if (dw == 0) { dw = dc.getTextWidthInPixels("0", font); }

        var gap = dw;
        var totalW = 10 * dw + gap;
        var x0 = cx - totalW / 2 + dw / 2;
        for (var i = 0; i < 10; i++) {
            var groupOffset = (i >= 5) ? gap : 0;
            var x = x0 + i * dw + groupOffset;
            var active = (i == _cursor);
            dc.setColor(active ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, cy, font, _digits[i].format("%d"), vc);
            if (active) {
                var halfH = dc.getFontHeight(font) / 2;
                dc.fillRectangle(x - dw / 2 + 1, cy + halfH - 2, dw - 2, 2);   // underline
            }
        }

        // Which half you're editing.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + dc.getFontHeight(font), Graphics.FONT_XTINY,
            (_cursor < 5) ? "easting" : "northing", vc);

        drawButtonHint(dc, 0.47, false, "+", Graphics.COLOR_WHITE, true);                 // UP, timed
        drawButtonHint(dc, 0.67, false, "-", Graphics.COLOR_WHITE, true);                 // DOWN, timed
        drawButtonHint(dc, 0.32, true, atLast() ? "GO" : "NEXT", Graphics.COLOR_WHITE, true);
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);            // always-on
    }
}

//! Drives GridEntryView: UP/DOWN change the digit, START advances (and on the last
//! digit computes the lat/lon and starts navigation), BACK steps left or cancels.
class GridEntryDelegate extends WatchUi.BehaviorDelegate {

    private var _view as GridEntryView;

    public function initialize(view as GridEntryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP) {
            _view.adjustDigit(1);
            WatchUi.requestUpdate();
            return true;
        } else if (k == WatchUi.KEY_DOWN) {
            _view.adjustDigit(-1);
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
        // Last digit: resolve the grid and navigate to it.
        var ll = Geo.mgrsToLatLon(_view.grid());
        if (ll == null) {
            var m = new MessageView("Bad grid", "Check the digits\nand try again.");
            WatchUi.pushView(m, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        }
        var nav = new ReturnNavView("Grid", ll[0], ll[1]);
        WatchUi.switchToView(nav, new SimpleBackDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! BACK steps the cursor left; at the first digit it falls through to cancel.
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
    // Seed prefix + digits from where we are (target is usually in the same square).
    var parts = splitOnSpace(Geo.latLonToMgrs(ll[0], ll[1]));   // [zb, sq, eeeee, nnnnn]
    var prefix = parts[0] + " " + parts[1];
    var digits = [] as Array<Number>;
    for (var i = 0; i < 5; i++) { digits.add(parts[2].substring(i, i + 1).toNumber()); }
    for (var i = 0; i < 5; i++) { digits.add(parts[3].substring(i, i + 1).toNumber()); }

    var v = new GridEntryView(prefix, digits);
    WatchUi.pushView(v, new GridEntryDelegate(v), WatchUi.SLIDE_LEFT);
}
