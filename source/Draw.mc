import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! How long the non-essential ("timed") button hints stay up after a screen
//! appears, before fading so the data stands alone.
const HINT_MS = 10000;

//! When the current screen's timed hints started showing (ms, System.getTimer()).
var gHintShownAt as Number = 0;

//! True while the timed hints should still be drawn.
function timedHintsVisible() as Boolean {
    return (System.getTimer() - $.gHintShownAt) < HINT_MS;
}

//! A view that shows timed hints holds one of these: call reset() in onShow()
//! and stop() in onHide(). It restarts the 10 s window and schedules the single
//! redraw that makes the hints disappear when the window ends.
class HintTimer {
    private var _timer as Timer.Timer?;

    public function initialize() {
    }

    public function reset() as Void {
        $.gHintShownAt = System.getTimer();
        stop();
        _timer = new Timer.Timer();
        _timer.start(method(:onExpire), HINT_MS, false);
    }

    public function stop() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    public function onExpire() as Void {
        WatchUi.requestUpdate();
    }
}

//! Draw a button hint as a short green arc on the bezel *exactly* where the
//! physical button is, with a small icon just inside it - the native Garmin
//! look. Positions follow the fenix / tactix button-only layout (START
//! upper-right, BACK lower-right, UP/DOWN on the left), so each arc sits right
//! at the button it describes instead of an arrow only approximating it.
//!
//! @param yFrac  vertical position as a fraction of height (START ~0.32, BACK ~0.68)
//! @param right  true for a right-edge button, false for a left-edge button
//! @param label  action word; mapped to an icon (e.g. "GO"->check, "+"->plus)
//! @param color  icon colour (the arc is always green); LT_GRAY dims a back hint
//! @param timed  true to fade with the hint timer; false for always-on
//!               confirm / cancel / back hints (so you can always exit a screen)
function drawButtonHint(dc as Dc, yFrac as Float, right as Boolean,
                        label as String, color as Graphics.ColorType, timed as Boolean) as Void {
    if (timed && !timedHintsVisible()) {
        return;
    }
    var w = dc.getWidth();
    var h = dc.getHeight();
    var cx = w / 2;
    var cy = h / 2;
    var rad = ((w < h) ? w : h) / 2 - 1;

    // Angle from centre to this button's point on the rim (0 = 3 o'clock, CCW+).
    var y = (h * yFrac).toNumber();
    var dyUp = cy - y;                                   // math-up positive
    var inside = rad * rad - dyUp * dyUp;
    var rimHalf = (inside > 0) ? Math.sqrt(inside) : 0.0;
    var dx = right ? rimHalf : -rimHalf;
    var angDeg = Math.atan2(dyUp, dx) * Geo.RAD2DEG;
    if (angDeg < 0.0) { angDeg += 360.0; }

    // Green arc hugging the bezel at that angle (a short, centred span).
    var span = 13.0;
    var pen = 6;
    var arcR = rad - 3;
    dc.setPenWidth(pen);
    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(cx, cy, arcR, Graphics.ARC_COUNTER_CLOCKWISE,
        (angDeg - span).toNumber(), (angDeg + span).toNumber());
    dc.setPenWidth(1);

    // Action icon just inside the arc.
    var ar = (angDeg * Geo.DEG2RAD);
    var ir = arcR - 16;
    var ix = (cx + ir * Math.cos(ar)).toNumber();
    var iy = (cy - ir * Math.sin(ar)).toNumber();
    drawHintIcon(dc, labelToIcon(label), ix, iy, 6, color);
}

//! Map an action word to an icon symbol.
function labelToIcon(label as String) as Symbol {
    if (label.equals("+")) { return :plus; }
    if (label.equals("-")) { return :minus; }
    if (label.equals("UP")) { return :up; }
    if (label.equals("DOWN")) { return :down; }
    if (label.equals("BACK")) { return :back; }
    if (label.equals("EXIT")) { return :exit; }
    if (label.equals("SAVE")) { return :save; }
    if (label.equals("TOOLS")) { return :menu; }
    return :check;   // GO / NEXT / DONE / CONFIRM and any other proceed action
}

//! Draw a small vector icon centred at (x, y); `s` is the half-size. Vectors (not
//! font glyphs/emoji) so they render identically on colour and 1-bit displays.
function drawHintIcon(dc as Dc, kind as Symbol, x as Number, y as Number,
                      s as Number, color as Graphics.ColorType) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(2);
    if (kind == :check) {
        dc.drawLine(x - s, y, x - s / 3, y + s);
        dc.drawLine(x - s / 3, y + s, x + s, y - s);
    } else if (kind == :plus) {
        dc.drawLine(x - s, y, x + s, y);
        dc.drawLine(x, y - s, x, y + s);
    } else if (kind == :minus) {
        dc.drawLine(x - s, y, x + s, y);
    } else if (kind == :up) {
        dc.drawLine(x - s, y + s / 2, x, y - s / 2);    // up chevron
        dc.drawLine(x, y - s / 2, x + s, y + s / 2);
    } else if (kind == :down) {
        dc.drawLine(x - s, y - s / 2, x, y + s / 2);    // down chevron
        dc.drawLine(x, y + s / 2, x + s, y - s / 2);
    } else if (kind == :back) {
        dc.drawLine(x + s / 2, y - s, x - s / 2, y);    // left chevron
        dc.drawLine(x - s / 2, y, x + s / 2, y + s);
    } else if (kind == :exit) {
        dc.drawLine(x - s, y - s, x + s, y + s);        // X
        dc.drawLine(x + s, y - s, x - s, y + s);
    } else if (kind == :save) {
        dc.drawLine(x, y - s, x, y + s / 2);            // down arrow into a tray
        dc.drawLine(x - s / 2, y, x, y + s / 2);
        dc.drawLine(x + s / 2, y, x, y + s / 2);
        dc.drawLine(x - s, y + s, x + s, y + s);
    } else if (kind == :menu) {
        dc.drawLine(x - s, y - s + 1, x + s, y - s + 1); // hamburger
        dc.drawLine(x - s, y, x + s, y);
        dc.drawLine(x - s, y + s - 1, x + s, y + s - 1);
    }
    dc.setPenWidth(1);
}

//! Shared drawing helpers that keep the UI legible across every screen size,
//! from a 280x280 Fenix down to a 156x156 Instinct 2S.

//! Largest-to-smallest font ladder used when fitting text to a width.
const FIT_FONTS = [
    Graphics.FONT_MEDIUM,
    Graphics.FONT_SMALL,
    Graphics.FONT_TINY,
    Graphics.FONT_XTINY
] as Array<Graphics.FontDefinition>;

//! Split a string on single spaces. (Monkey C strings have no built-in split.)
function splitOnSpace(s as String) as Array<String> {
    var parts = [] as Array<String>;
    var rest = s;
    var idx = rest.find(" ");
    while (idx != null) {
        parts.add(rest.substring(0, idx));
        rest = rest.substring(idx + 1, rest.length());
        idx = rest.find(" ");
    }
    parts.add(rest);
    return parts;
}

//! Draw a grid string centered on (cx, cy), as large as will fit within maxWidth.
//! If it won't fit on one line even at the smallest font, it breaks into two
//! lines the way a grid is read aloud ("18T WL" / "80735 04700").
//! Returns the half-height of the drawn block, so callers can place a label
//! above and a hint below without overlapping.
function drawGridFitted(dc as Dc, cx as Number, cy as Number, text as String,
                        color as Graphics.ColorType, maxWidth as Number) as Number {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // Try to keep it on one line.
    for (var i = 0; i < FIT_FONTS.size(); i++) {
        var f = FIT_FONTS[i];
        if (dc.getTextWidthInPixels(text, f) <= maxWidth) {
            dc.drawText(cx, cy, f, text, center);
            return dc.getFontHeight(f) / 2;
        }
    }

    // Two-line fallback. Break the way the value reads aloud: an MGRS grid splits
    // into "<zone><band> <square>" / "<easting> <northing>" (4 parts), a decimal
    // lat/long into "<lat>," / "<lon>" (2 parts). Anything else just wraps at the
    // existing space so a too-wide string never overflows on one line.
    var parts = splitOnSpace(text);
    var line1 = text;
    var line2 = "";
    if (parts.size() >= 4) {
        line1 = parts[0] + " " + parts[1];
        line2 = parts[2] + " " + parts[3];
    } else if (parts.size() == 2) {
        line1 = parts[0];
        line2 = parts[1];
    }

    // Largest font that fits BOTH lines.
    var font = Graphics.FONT_XTINY;
    for (var i = 0; i < FIT_FONTS.size(); i++) {
        var f = FIT_FONTS[i];
        if (dc.getTextWidthInPixels(line1, f) <= maxWidth &&
            dc.getTextWidthInPixels(line2, f) <= maxWidth) {
            font = f;
            break;
        }
    }

    var h = dc.getFontHeight(font);
    dc.drawText(cx, cy - h / 2, font, line1, center);
    dc.drawText(cx, cy + h / 2, font, line2, center);
    return h;   // half of the two-line (2*h) block
}
