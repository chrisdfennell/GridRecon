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

//! Draw a button hint: a short label at the screen rim, beside a physical button,
//! with a small marker pointing out to that button. Positions follow the
//! fenix / tactix button-only layout - START upper-right, BACK lower-right,
//! UP/DOWN on the left - so the user can see at a glance what each button does.
//!
//! @param yFrac  vertical position as a fraction of height (START ~0.32, BACK ~0.68)
//! @param right  true for a right-edge button, false for a left-edge button
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

    var y = (h * yFrac).toNumber();
    var dy = y - cy;
    var inside = rad * rad - dy * dy;
    var rimHalf = (inside > 0) ? Math.sqrt(inside) : 0.0;

    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    if (right) {
        var rimX = cx + rimHalf;
        var tipX = (rimX - 3).toNumber();
        var baseX = tipX - 11;
        dc.fillPolygon([[baseX, y - 6], [baseX, y + 6], [tipX, y]] as Array<[Numeric, Numeric]>);
        dc.drawText(baseX - 6, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    } else {
        var rimX = cx - rimHalf;
        var tipX = (rimX + 3).toNumber();
        var baseX = tipX + 11;
        dc.fillPolygon([[baseX, y - 6], [baseX, y + 6], [tipX, y]] as Array<[Numeric, Numeric]>);
        dc.drawText(baseX + 6, y, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
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

    // Two-line fallback. Split into "<zone><band> <square>" and "<easting> <northing>".
    var parts = splitOnSpace(text);
    var line1 = text;
    var line2 = "";
    if (parts.size() >= 4) {
        line1 = parts[0] + " " + parts[1];
        line2 = parts[2] + " " + parts[3];
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
