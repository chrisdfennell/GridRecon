import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.Timer;
import Toybox.WatchUi;

//! Live compass: a rotating card with a fixed lubber index at the top (the way you're
//! facing), the cardinals sitting at their real-world angles, and the heading read out
//! big in the middle. Magnetometer-only, so it works with GPS off or jammed - the whole
//! point of the app. The reading follows the same convention as the rest of GridRecon:
//! the watch's heading is shown straight through, tagged "magnetic" when a declination
//! offset is set and "true" otherwise (see compassMagDeg / CompassSightView).
class CompassView extends WatchUi.View {

    private var _timer as Timer.Timer?;

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        // Keep the magnetometer powered so the heading populates (see ReturnNavView).
        if (Sensor has :enableSensorEvents) {
            Sensor.enableSensorEvents(method(:onSensorEvent));
        }
        // 5 Hz: smooth enough that the card glides as you turn without thrashing the battery.
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    public function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        if (Sensor has :enableSensorEvents) {
            Sensor.enableSensorEvents(null);
        }
    }

    public function onTick() as Void {
        WatchUi.requestUpdate();
    }

    public function onSensorEvent(info as Sensor.Info) as Void {
        // Intentionally empty - we read getInfo() in onUpdate.
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = ((w < h) ? w : h) / 2.0d;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var hd = compassMagDeg();
        if (hd == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "No compass", vc);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (cy + h * 0.18).toNumber(), Graphics.FONT_XTINY,
                "this watch has no\nmagnetometer", vc);
            drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
            return;
        }

        drawDial(dc, cx, cy, r, hd);

        // Centre readout: heading big, the 16-point cardinal below it, then the frame tag.
        var mag = Settings.hasDeclination();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy - h * 0.05).toNumber(), Graphics.FONT_NUMBER_MEDIUM, headingBig(hd),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + h * 0.12).toNumber(), Graphics.FONT_TINY, cardinal16(hd), vc);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + h * 0.22).toNumber(), Graphics.FONT_XTINY, mag ? "magnetic" : "true", vc);

        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
    }

    //! The rotating card: tick ring + cardinal letters placed at (bearing - heading) so
    //! they sit where they really are, a red north arrow that rotates with them, and the
    //! one fixed yellow index at the top that marks the way the watch is pointed.
    private function drawDial(dc as Dc, cx as Number, cy as Number, r as Double, hd as Double) as Void {
        var rim = r - 2.0d;

        // Tick ring every 15 deg: cardinals longest, intercardinals medium, the rest short.
        for (var b = 0; b < 360; b += 15) {
            var ang = b.toDouble() - hd;
            var isCard = (b % 90 == 0);
            var isInter = (b % 45 == 0);
            var len = isCard ? (r * 0.15d) : (isInter ? (r * 0.10d) : (r * 0.06d));
            if (b == 0) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
            } else if (isCard) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
            }
            var p1 = polar(cx, cy, ang, rim);
            var p2 = polar(cx, cy, ang, rim - len);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        dc.setPenWidth(1);

        // North arrowhead: a slim red triangle at the rim so north is obvious even on a
        // 1-bit screen where the red collapses to white - the shape carries it.
        var nAng = -hd;
        var tip = polar(cx, cy, nAng, rim);
        var bl = polar(cx, cy, nAng - 7.0d, rim - r * 0.16d);
        var br = polar(cx, cy, nAng + 7.0d, rim - r * 0.16d);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([tip, bl, br] as Array<[Numeric, Numeric]>);

        // Cardinal letters, upright (legible) but orbiting the rim with the card.
        var letters = ["N", "E", "S", "W"] as Array<String>;
        var bear = [0, 90, 180, 270] as Array<Number>;
        for (var i = 0; i < 4; i++) {
            var pos = polar(cx, cy, bear[i].toDouble() - hd, r * 0.66d);
            dc.setColor(i == 0 ? Graphics.COLOR_RED : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pos[0], pos[1], Graphics.FONT_TINY, letters[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Fixed lubber index at the very top: a yellow triangle pointing into the dial,
        // marking "this is the way the watch is facing". Does not rotate.
        var topY = (cy - rim).toNumber();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx, (topY + r * 0.13d).toNumber()],
            [(cx - r * 0.06d).toNumber(), topY],
            [(cx + r * 0.06d).toNumber(), topY]
        ] as Array<[Numeric, Numeric]>);
    }

    //! Big-font heading in the user's unit: degrees "348°", mils the bare 4-digit number
    //! (the NUMBER font carries no letters). Same formatting as the sight screen.
    private function headingBig(deg as Double) as String {
        var v = Settings.bearingFromDegrees(deg);
        return Settings.useMils() ? v.format("%04d") : (v.format("%03d") + "°");
    }

    //! Screen point at radius rr and compass angle phi (degrees, 0 = up, clockwise).
    private function polar(cx as Number, cy as Number, phiDeg as Double, rr as Double) as [Number, Number] {
        var p = phiDeg * Geo.DEG2RAD;
        return [(cx + rr * Math.sin(p)).toNumber(), (cy - rr * Math.cos(p)).toNumber()];
    }
}

//! Degrees -> 16-point compass name ("N", "NNE", "NE", ... "NNW"). The index is the
//! heading rounded to the nearest 22.5 deg sector, wrapped back to 0..15.
function cardinal16(deg as Double) as String {
    var names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                 "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"] as Array<String>;
    var i = ((norm360(deg) / 22.5d) + 0.5d).toNumber() % 16;
    return names[i];
}
