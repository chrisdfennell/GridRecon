import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.Timer;
import Toybox.WatchUi;

//! Live navigation back to a saved mark: a hybrid arrow (compass heading when
//! you're still, GPS course when moving), the distance counting down, and the
//! bearing as the always-trustworthy number. Refreshes once a second.
class ReturnNavView extends WatchUi.View {

    private var _name as String;
    private var _lat as Double;
    private var _lon as Double;
    private var _timer as Timer.Timer?;
    private var _arrivedBuzzed as Boolean = false;   // vibrate once per arrival

    public function initialize(name as String, lat as Double, lon as Double) {
        View.initialize();
        _name = name;
        _lat = lat;
        _lon = lon;
    }

    public function onShow() as Void {
        gpsAcquire();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
        // Keep the magnetometer powered so the heading arrow has data: on some
        // devices Sensor.getInfo().heading is only populated while sensor events
        // are enabled. The handler itself is a no-op; we read getInfo() in onUpdate.
        if (Sensor has :enableSensorEvents) {
            Sensor.enableSensorEvents(method(:onSensorEvent));
        }
    }

    public function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        if (Sensor has :enableSensorEvents) {
            Sensor.enableSensorEvents(null);
        }
        gpsRelease();
    }

    public function onTick() as Void {
        WatchUi.requestUpdate();
    }

    public function onSensorEvent(info as Sensor.Info) as Void {
        // Intentionally empty - see onShow().
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        drawButtonHint(dc, 0.68, true, "EXIT", Graphics.COLOR_LT_GRAY, false);

        var ll = currentLatLon();
        if (ll == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Waiting for GPS…", vc);
            return;
        }

        var inv = Geo.inverse(ll[0], ll[1], _lat, _lon);
        var dist = inv[0];
        var brng = inv[1];

        // Mark name across the top.
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.12).toNumber(), Graphics.FONT_XTINY, _name.toUpper(), vc);

        // Arrived: buzz once so you don't have to be watching the screen.
        if (dist < 12.0d) {
            if (!_arrivedBuzzed && (Attention has :vibrate)) {
                Attention.vibrate([new Attention.VibeProfile(75, 400)] as Array<Attention.VibeProfile>);
            }
            _arrivedBuzzed = true;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "You're here", vc);
            return;
        }
        // Re-arm the arrival buzz once you've clearly moved away again.
        if (dist > 25.0d) {
            _arrivedBuzzed = false;
        }

        var minDim = (w < h) ? w : h;
        var arrowCy = (cy - h * 0.04).toNumber();
        var hd = headingDeg();
        if (hd != null) {
            drawArrow(dc, cx, arrowCy, brng - hd, (minDim * 0.27).toNumber());
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, arrowCy, Graphics.FONT_XTINY, "walk a few steps\nto aim the arrow", vc);
        }

        // Distance (the big number) and the bearing fallback. The bearing is shown
        // in magnetic (the number to dial on a compass) when a declination offset is
        // set, true north otherwise.
        var steer = Settings.trueToMag(brng);
        var ref = Settings.hasDeclination() ? "°M" : "°";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + h * 0.24).toNumber(), Graphics.FONT_NUMBER_MEDIUM, formatDistance(dist), vc);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + h * 0.40).toNumber(), Graphics.FONT_XTINY,
            "bearing " + steer.toNumber().format("%03d") + ref, vc);
    }

    //! Filled arrowhead pointing at a relative bearing (0 = straight up).
    //! White so it stays visible on monochrome displays.
    private function drawArrow(dc as Dc, cx as Number, cy as Number, relDeg as Double, r as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var pts = [
            polar(cx, cy, relDeg, r),
            polar(cx, cy, relDeg + 148.0d, r * 0.62),
            polar(cx, cy, relDeg, r * 0.22),
            polar(cx, cy, relDeg - 148.0d, r * 0.62)
        ] as Array<[Numeric, Numeric]>;
        dc.fillPolygon(pts);
    }

    //! Point at radius r and compass angle phi (degrees, 0 = up, clockwise).
    private function polar(cx as Number, cy as Number, phiDeg as Double, r as Numeric) as [Number, Number] {
        var p = phiDeg * Geo.DEG2RAD;
        return [(cx + r * Math.sin(p)).toNumber(), (cy - r * Math.cos(p)).toNumber()];
    }
}

//! Below this ground speed (~3.6 km/h) the GPS course is just noise, so we don't
//! steer the arrow with it - the compass takes over, or we ask for a few steps.
const MOVE_MIN_MPS = 1.0d;

//! Heading in degrees TRUE - the same frame as the bearing to the target, so the
//! arrow's relative angle is correct.
//!
//! The magnetometer compass works standing still and is tried first. Its reading is
//! magnetic, so we add the declination offset to bring it to true (with no offset
//! set, this is a no-op). The GPS course is already true north but is only
//! trustworthy while moving, so it's a fallback gated on a walking speed. Null when
//! neither is usable - the caller then shows the "walk a few steps" hint.
function headingDeg() as Double? {
    var s = Sensor.getInfo();
    if (s != null && s.heading != null) {
        return Settings.magToTrue(s.heading.toDouble() * Geo.RAD2DEG);
    }
    var info = $.gLastInfo;
    if (info != null && info.heading != null && info.speed != null && info.speed >= MOVE_MIN_MPS) {
        return norm360(info.heading.toDouble() * Geo.RAD2DEG);
    }
    return null;
}

function norm360(d as Double) as Double {
    while (d < 0.0d)    { d += 360.0d; }
    while (d >= 360.0d) { d -= 360.0d; }
    return d;
}

//! Distance in the user's units: metric "420 m" / "1.4 km", imperial "460 yd" / "0.9 mi".
function formatDistance(m as Double) as String {
    if (Settings.useImperial()) {
        var yd = m / 0.9144d;
        if (yd < 1760.0d) {
            return yd.format("%.0f") + " yd";
        }
        return (m / 1609.344d).format("%.1f") + " mi";
    }
    if (m < 1000.0d) {
        return m.format("%.0f") + " m";
    }
    return (m / 1000.0d).format("%.1f") + " km";
}
