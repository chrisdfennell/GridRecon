import Toybox.Lang;
import Toybox.Test;

//! Tests for the sunrise/sunset astronomy in the Sun module. The equation is standard
//! and pure given (lat, lon, date), so it pins cleanly. Goldens are physical facts, not
//! recomputed from this code: a ~12 h equinox day at the equator, and the Arctic
//! polar-day / polar-night cases at Tromso. (nearD lives in GeoTest.mc.)

//! Julian Day Number is anchored: 2000-01-01 12:00 UT is JD 2451545.
(:test)
function testJulianDay(logger as Test.Logger) as Boolean {
    Test.assertMessage(Sun.julianDay(2000, 1, 1) == 2451545l, "J2000 epoch: " + Sun.julianDay(2000, 1, 1));
    return true;
}

//! HH:MM formatting zero-pads and wraps.
(:test)
function testFmtHM(logger as Test.Logger) as Boolean {
    Test.assertMessage(Sun.fmtHM(365).equals("06:05"), "06:05: " + Sun.fmtHM(365));
    Test.assertMessage(Sun.fmtHM(0).equals("00:00"),   "midnight: " + Sun.fmtHM(0));
    Test.assertMessage(Sun.fmtHM(1439).equals("23:59"), "23:59: " + Sun.fmtHM(1439));
    Test.assertMessage(Sun.fmtHM(1440).equals("00:00"), "wrap: " + Sun.fmtHM(1440));
    return true;
}

//! Equinox at the equator/prime meridian: sunrise ~06:00, sunset ~18:00 UTC, with a
//! daylight span just over 12 h (the -0.833 deg refraction/disc term stretches it).
(:test)
function testSunEquinoxEquator(logger as Test.Logger) as Boolean {
    var s = Sun.sunTimesUtc(0.0d, 0.0d, 2024, 3, 20);
    logger.debug("equinox: code=" + s[0] + " rise=" + Sun.fmtHM(s[1]) + " set=" + Sun.fmtHM(s[2]));
    Test.assertMessage(s[0] == Sun.NORMAL, "normal day");
    Test.assertMessage(s[1] > 345 && s[1] < 375, "rise near 06:00 UTC: " + Sun.fmtHM(s[1]));
    Test.assertMessage(s[2] > 1075 && s[2] < 1105, "set near 18:00 UTC: " + Sun.fmtHM(s[2]));
    var dayLen = s[2] - s[1];
    Test.assertMessage(dayLen > 715 && dayLen < 740, "~12 h day: " + dayLen + " min");
    return true;
}

//! Tromso (69.65 N) above the Arctic Circle: polar night at the winter solstice (sun
//! never rises) and midnight sun at the summer solstice (sun never sets).
(:test)
function testSunPolar(logger as Test.Logger) as Boolean {
    var winter = Sun.sunTimesUtc(69.6492d, 18.9560d, 2024, 12, 21);
    Test.assertMessage(winter[0] == Sun.ALWAYS_DN, "polar night: code=" + winter[0]);

    var summer = Sun.sunTimesUtc(69.6492d, 18.9560d, 2024, 6, 21);
    Test.assertMessage(summer[0] == Sun.ALWAYS_UP, "midnight sun: code=" + summer[0]);
    return true;
}
