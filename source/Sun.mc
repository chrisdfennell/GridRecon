import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Sunrise / sunset for your current position and today's date.
//!
//! Pure astronomy - no permissions, no network. The math is the standard low-precision
//! "sunrise equation" (good to about a minute, which is well past what matters when
//! you're deciding whether you'll make camp before dark). It runs in UTC; the view
//! adds the watch's timezone offset to show local clock times.
module Sun {

    const PI = 3.141592653589793d;
    const D2R = PI / 180.0d;
    const R2D = 180.0d / PI;

    // Result codes for sunTimesUtc()'s first element.
    const NORMAL    = 0;   // rise/set both occur
    const ALWAYS_UP = 1;   // polar day - sun never sets
    const ALWAYS_DN = 2;   // polar night - sun never rises

    //! Sunrise and sunset for a position and calendar date, in UTC minutes-of-day.
    //! @return [code, riseMinUtc, setMinUtc]; on a polar day/night the two minute
    //!         values are unused (return 0) and `code` says which case it is.
    function sunTimesUtc(latDeg as Double, lonDeg as Double,
                         year as Number, month as Number, day as Number) as Array<Number> {
        var jdn = julianDay(year, month, day);
        var n = jdn.toDouble() - 2451545.0d + 0.0008d;   // days since J2000 (noon-based)

        var lw = -lonDeg;                                // sunrise eqn uses west-positive longitude
        var jStar = n - lw / 360.0d;                     // mean solar noon

        var m = mod360(357.5291d + 0.98560028d * jStar); // solar mean anomaly (deg)
        var mr = m * D2R;
        var c = 1.9148d * Math.sin(mr) + 0.0200d * Math.sin(2.0d * mr) + 0.0003d * Math.sin(3.0d * mr);
        var lambda = mod360(m + c + 180.0d + 102.9372d); // ecliptic longitude (deg)
        var lr = lambda * D2R;

        var jTransit = 2451545.0d + jStar + 0.0053d * Math.sin(mr) - 0.0069d * Math.sin(2.0d * lr);

        var sinDecl = Math.sin(lr) * Math.sin(23.44d * D2R);
        var cosDecl = Math.sqrt(1.0d - sinDecl * sinDecl);
        var latR = latDeg * D2R;

        // Hour angle of sunrise; -0.833 deg accounts for refraction + the sun's radius.
        var cosH = (Math.sin(-0.833d * D2R) - Math.sin(latR) * sinDecl) / (Math.cos(latR) * cosDecl);
        if (cosH > 1.0d)  { return [ALWAYS_DN, 0, 0] as Array<Number>; }
        if (cosH < -1.0d) { return [ALWAYS_UP, 0, 0] as Array<Number>; }
        var h = Math.acos(cosH) * R2D;                   // half-day arc in degrees

        var rise = jdToMinUtc(jTransit - h / 360.0d);
        var set  = jdToMinUtc(jTransit + h / 360.0d);
        return [NORMAL, rise, set] as Array<Number>;
    }

    //! Gregorian calendar date -> Julian Day Number (integer, noon-based). Standard
    //! Fliegel-Van Flandern algorithm with integer division throughout.
    function julianDay(y as Number, m as Number, d as Number) as Long {
        var a = (14 - m) / 12;
        var yy = y + 4800 - a;
        var mm = m + 12 * a - 3;
        return (d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045).toLong();
    }

    //! A Julian Date -> UTC minutes since midnight [0,1440). JD's fractional part is
    //! measured from noon, so a half-day shift puts it on the midnight boundary.
    function jdToMinUtc(jd as Double) as Number {
        var x = jd + 0.5d;
        var frac = x - x.toLong().toDouble();            // toLong truncates = floor for positive jd
        var mins = (frac * 1440.0d + 0.5d).toLong();     // round to the nearest minute
        return (mins % 1440l).toNumber();
    }

    function mod360(d as Double) as Double {
        var x = d;
        while (x < 0.0d)    { x += 360.0d; }
        while (x >= 360.0d) { x -= 360.0d; }
        return x;
    }

    //! Minutes-of-day -> "HH:MM" (24-hour). Wraps so a value outside [0,1440) is safe.
    function fmtHM(min as Number) as String {
        var m = ((min % 1440) + 1440) % 1440;
        return (m / 60).format("%02d") + ":" + (m % 60).format("%02d");
    }
}

//! "Sun": sunrise and sunset for where you are, today, in local time. Needs a position
//! (live or last-known); like the other compute tools it leans on the cached fix when
//! GPS is off. Read-only - BACK exits.
class SunView extends WatchUi.View {

    private var _hints as HintTimer = new HintTimer();

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var tinyH = dc.getFontHeight(Graphics.FONT_TINY);

        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);

        var ll = currentLatLon();
        if (ll == null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "No position yet", vc);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + tinyH, Graphics.FONT_XTINY,
                "need a fix to find\nyour sunrise/sunset", vc);
            return;
        }

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var s = Sun.sunTimesUtc(ll[0], ll[1], now.year, now.month, now.day);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.18).toNumber(), Graphics.FONT_TINY, "Sun today", vc);

        if (s[0] == Sun.ALWAYS_UP) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Up all day", vc);
            return;
        }
        if (s[0] == Sun.ALWAYS_DN) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Down all day", vc);
            return;
        }

        var tzMin = System.getClockTime().timeZoneOffset / 60;
        var rise = s[1] + tzMin;
        var set  = s[2] + tzMin;

        // Day length is the UTC difference (the timezone offset cancels), wrapped.
        var dayLen = s[2] - s[1];
        if (dayLen < 0) { dayLen += 1440; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy - tinyH).toNumber(), Graphics.FONT_SMALL, "Rise  " + Sun.fmtHM(rise), vc);
        dc.drawText(cx, (cy + tinyH).toNumber(), Graphics.FONT_SMALL, "Set   " + Sun.fmtHM(set), vc);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (cy + tinyH * 5 / 2).toNumber(), Graphics.FONT_XTINY,
            "day " + (dayLen / 60).format("%d") + "h " + (dayLen % 60).format("%02d") + "m", vc);
    }
}
