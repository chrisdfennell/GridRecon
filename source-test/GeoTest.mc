import Toybox.Lang;
import Toybox.Test;

//! Unit tests for the Geo geodesy + MGRS engine - the riskiest code in the app,
//! since a wrong letter or an off-by-one in the grid math puts someone in the
//! wrong 100 km square. Pure and deterministic, so it's ideal to pin with tests.
//!
//! Golden values are INDEPENDENT of this codebase:
//!   - MGRS strings come from the GEOTRANS-backed Python `mgrs` library.
//!   - inverse()/project() goldens are recomputed from the same closed-form
//!     models Geo uses (haversine inverse, spherical forward), so they pin the
//!     implementation to float precision.
//!
//! This file lives in source-test/ and is only pulled in by monkey-test.jungle,
//! so it never ships in a production build. Run it with tools/runtests.ps1.

// =============================================================================
//  Helpers
// =============================================================================

//! Absolute difference of two Doubles within tolerance (no Double.abs in older APIs).
function nearD(a as Double, b as Double, tol as Double) as Boolean {
    var d = a - b;
    if (d < 0.0d) { d = -d; }
    return d <= tol;
}

//! Compare two 5-digit MGRS grid components, allowing a 1 m slack and handling
//! the wrap at the 100 km boundary (e.g. 00000 vs 99999 is a 1 m difference).
function digitsClose(a as Number, b as Number) as Boolean {
    var d = a - b;
    if (d < 0) { d = -d; }
    if (d > 50000) { d = 100000 - d; }
    return d <= 1;
}

//! Assert that latLonToMgrs(lat, lon) yields the expected zone+band, 100 km
//! square, and easting/northing (the latter within 1 m). Returns on first failure.
function assertMgrs(logger as Test.Logger, lat as Double, lon as Double,
                    prefix as String, square as String, e as Number, n as Number) as Void {
    var got = Geo.latLonToMgrs(lat, lon);
    logger.debug(prefix + " " + square + " " + e.format("%05d") + " " + n.format("%05d") + "  <=  " + got);

    // Fixed-width MGRS form: "ZZB SQ EEEEE NNNNN".
    var gotPrefix = got.substring(0, 3);
    var gotSquare = got.substring(4, 6);
    var gotE = got.substring(7, 12).toNumber();
    var gotN = got.substring(13, 18).toNumber();

    Test.assertMessage(gotPrefix.equals(prefix),
        "zone+band: expected " + prefix + " got " + gotPrefix + " (" + got + ")");
    Test.assertMessage(gotSquare.equals(square),
        "100km square: expected " + square + " got " + gotSquare + " (" + got + ")");
    Test.assertMessage(gotE != null && digitsClose(gotE, e),
        "easting: expected ~" + e + " got " + gotE + " (" + got + ")");
    Test.assertMessage(gotN != null && digitsClose(gotN, n),
        "northing: expected ~" + n + " got " + gotN + " (" + got + ")");
}

// =============================================================================
//  MGRS conversion
// =============================================================================

//! Known landmarks across both hemispheres, multiple lat bands, even/odd zones
//! and zone boundaries. Goldens from the GEOTRANS-backed `mgrs` library.
(:test)
function testMgrsKnownPoints(logger as Test.Logger) as Boolean {
    assertMgrs(logger,  40.689167d,  -74.044444d, "18T", "WL", 80740,  4691); // Statue of Liberty
    assertMgrs(logger,  38.889484d,  -77.035278d, "18S", "UJ", 23479,  6481); // Washington Monument
    assertMgrs(logger,  51.476852d,   -0.000500d, "30U", "YC",  8287,  7121); // Greenwich (prime meridian)
    assertMgrs(logger,  35.658581d,  139.745438d, "54S", "UE", 86441, 46806); // Tokyo Tower
    return true;
}

//! Southern hemisphere exercises the 10,000,000 m false-northing branch and the
//! southern band letters (F/H/K).
(:test)
function testMgrsSouthernHemisphere(logger as Test.Logger) as Boolean {
    assertMgrs(logger, -33.856785d,  151.215288d, "56H", "LH", 34899, 52290); // Sydney Opera House
    assertMgrs(logger, -22.951916d,  -43.210487d, "23K", "PQ", 83477, 60685); // Christ the Redeemer
    assertMgrs(logger, -33.924869d,   18.424055d, "34H", "BH", 61877, 43185); // Cape Town
    assertMgrs(logger, -54.801910d,  -68.302948d, "19F", "EV", 44808, 27028); // Ushuaia (far south)
    return true;
}

//! Edge cases: zero-padded single-digit zone, the equator, and a high-north band.
(:test)
function testMgrsEdgeCases(logger as Test.Logger) as Boolean {
    assertMgrs(logger,  61.218056d, -149.900278d, "06V", "UN", 44248, 90531); // Anchorage - zone "06"
    assertMgrs(logger,   0.000000d,    0.000001d, "31N", "AA", 66021,     0); // equator @ prime meridian
    assertMgrs(logger,  69.649200d,   18.955600d, "34W", "DC", 20665, 28080); // Tromso - band W
    return true;
}

//! Lower precision drops least-significant figures (truncation), keeping the
//! leading digits of the full 1 m grid. Precision is clamped to 1..5.
(:test)
function testMgrsPrecision(logger as Test.Logger) as Boolean {
    var lat = 40.689167d; var lon = -74.044444d;   // full: 18T WL 80740 04691
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 5).equals("18T WL 80740 04691"), Geo.mgrsAtPrecision(lat, lon, 5));
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 4).equals("18T WL 8074 0469"),   Geo.mgrsAtPrecision(lat, lon, 4));
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 3).equals("18T WL 807 046"),     Geo.mgrsAtPrecision(lat, lon, 3));
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 2).equals("18T WL 80 04"),       Geo.mgrsAtPrecision(lat, lon, 2));
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 1).equals("18T WL 8 0"),         Geo.mgrsAtPrecision(lat, lon, 1));
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 0).equals(Geo.mgrsAtPrecision(lat, lon, 1)), "clamp low");
    Test.assertMessage(Geo.mgrsAtPrecision(lat, lon, 9).equals(Geo.mgrsAtPrecision(lat, lon, 5)), "clamp high");
    return true;
}

//! The grid string is always exactly "ZZB SQ EEEEE NNNNN" (18 chars, 3 spaces).
(:test)
function testMgrsFormat(logger as Test.Logger) as Boolean {
    var s = Geo.latLonToMgrs(40.689167d, -74.044444d);
    Test.assertMessage(s.length() == 18, "expected 18-char MGRS, got " + s.length() + ": " + s);
    var spaces = 0;
    for (var i = 0; i < s.length(); i++) {
        if (s.substring(i, i + 1).equals(" ")) { spaces++; }
    }
    Test.assertMessage(spaces == 3, "expected 3 spaces, got " + spaces + ": " + s);
    return true;
}

// =============================================================================
//  Inverse geodesic (distance + bearing to a mark)
// =============================================================================

//! Haversine distance and initial bearing against goldens recomputed from the
//! same model. Long leg + short tactical leg.
(:test)
function testInverse(logger as Test.Logger) as Boolean {
    var a = Geo.inverse(40.689167d, -74.044444d, 38.889484d, -77.035278d); // Liberty -> Washington
    logger.debug("inverse long: dist=" + a[0] + " brng=" + a[1]);
    Test.assertMessage(nearD(a[0], 324540.4976d, 1.0d), "long dist " + a[0]);
    Test.assertMessage(nearD(a[1], 232.9004d, 0.01d),    "long bearing " + a[1]);

    var b = Geo.inverse(45.0d, -93.0d, 45.005d, -92.995d);
    logger.debug("inverse short: dist=" + b[0] + " brng=" + b[1]);
    Test.assertMessage(nearD(b[0], 680.9172d, 0.5d), "short dist " + b[0]);
    Test.assertMessage(nearD(b[1], 35.2614d, 0.01d), "short bearing " + b[1]);
    return true;
}

// =============================================================================
//  Forward projection (target from bearing + range)
// =============================================================================

//! Spherical forward solution against goldens recomputed from the same model.
(:test)
function testProject(logger as Test.Logger) as Boolean {
    var p = Geo.project(45.0d, -93.0d, 45.0d, 800.0d);
    logger.debug("project: lat=" + p[0] + " lon=" + p[1]);
    Test.assertMessage(nearD(p[0],  45.00508711d, 1.0e-6d), "lat " + p[0]);
    Test.assertMessage(nearD(p[1], -92.99280479d, 1.0e-6d), "lon " + p[1]);

    // Due east on the equator: latitude unchanged, longitude increases.
    var e = Geo.project(0.0d, 0.0d, 90.0d, 1000.0d);
    Test.assertMessage(nearD(e[0], 0.0d, 1.0e-9d),       "equator lat " + e[0]);
    Test.assertMessage(nearD(e[1], 0.00899322d, 1.0e-6d), "equator lon " + e[1]);
    return true;
}

//! project() then inverse() must recover the original range and the back-azimuth
//! of the outbound bearing - the exact round trip "Find a target" relies on.
(:test)
function testProjectInverseRoundTrip(logger as Test.Logger) as Boolean {
    var lat = 45.0d; var lon = -93.0d; var az = 70.0d; var dist = 1500.0d;
    var p = Geo.project(lat, lon, az, dist);
    var inv = Geo.inverse(lat, lon, p[0], p[1]);
    logger.debug("roundtrip: dist=" + inv[0] + " (want " + dist + ") brng=" + inv[1] + " (want " + az + ")");
    Test.assertMessage(nearD(inv[0], dist, 0.5d), "roundtrip dist " + inv[0]);
    Test.assertMessage(nearD(inv[1], az, 0.01d),  "roundtrip bearing " + inv[1]);
    return true;
}

// =============================================================================
//  Back-azimuth
// =============================================================================

//! backAzimuth() adds 180 and stays in [0,360).
(:test)
function testBackAzimuth(logger as Test.Logger) as Boolean {
    Test.assertMessage(nearD(Geo.backAzimuth(0.0d),   180.0d, 1.0e-9d), "0");
    Test.assertMessage(nearD(Geo.backAzimuth(90.0d),  270.0d, 1.0e-9d), "90");
    Test.assertMessage(nearD(Geo.backAzimuth(180.0d),   0.0d, 1.0e-9d), "180");
    Test.assertMessage(nearD(Geo.backAzimuth(270.0d),  90.0d, 1.0e-9d), "270");
    Test.assertMessage(nearD(Geo.backAzimuth(350.0d), 170.0d, 1.0e-9d), "350");
    return true;
}

// =============================================================================
//  MGRS inverse (grid -> lat/lon)
// =============================================================================

//! Assert mgrsToLatLon yields the expected SW-corner lat/lon (within ~3 m).
function assertLatLon(logger as Test.Logger, grid as String, lat as Double, lon as Double) as Void {
    var ll = Geo.mgrsToLatLon(grid);
    Test.assertMessage(ll != null, "parse failed: " + grid);
    logger.debug(grid + "  ->  " + ll[0] + ", " + ll[1]);
    Test.assertMessage(nearD(ll[0], lat, 3.0e-5d), "lat " + ll[0] + " want " + lat + " (" + grid + ")");
    Test.assertMessage(nearD(ll[1], lon, 3.0e-5d), "lon " + ll[1] + " want " + lon + " (" + grid + ")");
}

//! Inverse against GEOTRANS-derived corner coordinates, both hemispheres, even/odd
//! zones, high/low bands.
(:test)
function testMgrsToLatLon(logger as Test.Logger) as Boolean {
    assertLatLon(logger, "18T WL 80740 04691",  40.6891621d,  -74.0444517d);
    assertLatLon(logger, "56H LH 34899 52290", -33.8567885d,  151.2152833d); // S hemisphere
    assertLatLon(logger, "06V UN 44248 90531",  61.2180477d, -149.9002804d); // zone 06, even
    assertLatLon(logger, "19F EV 44808 27028", -54.8019167d,  -68.3029546d); // far south
    assertLatLon(logger, "34W DC 20665 28080",  69.6491925d,   18.9555947d); // high north
    return true;
}

//! latLon -> MGRS -> latLon lands within ~3 m (back at the cell's SW corner).
(:test)
function testMgrsRoundTrip(logger as Test.Logger) as Boolean {
    var pts = [
        [ 40.6891d,  -74.0444d],
        [-33.8500d,  151.2100d],
        [ 61.2100d, -149.9000d],
        [ 35.6500d,  139.7400d]
    ] as Array<Array<Double>>;
    for (var i = 0; i < pts.size(); i++) {
        var grid = Geo.latLonToMgrs(pts[i][0], pts[i][1]);
        var ll = Geo.mgrsToLatLon(grid);
        Test.assertMessage(ll != null, "round-trip parse: " + grid);
        Test.assertMessage(nearD(ll[0], pts[i][0], 3.0e-5d), "rt lat " + grid);
        Test.assertMessage(nearD(ll[1], pts[i][1], 3.0e-5d), "rt lon " + grid);
    }
    return true;
}

//! Parsing: compact == spaced, lower precision works, garbage/invalid -> null.
(:test)
function testMgrsToLatLonParsing(logger as Test.Logger) as Boolean {
    var a = Geo.mgrsToLatLon("18T WL 80740 04691");
    var b = Geo.mgrsToLatLon("18TWL8074004691");
    Test.assertMessage(a != null && b != null, "both parse");
    Test.assertMessage(nearD(a[0], b[0], 1.0e-9d) && nearD(a[1], b[1], 1.0e-9d), "spaced == compact");

    Test.assertMessage(Geo.mgrsToLatLon("18T WL 807 046") != null, "3-figure parses");
    Test.assertMessage(Geo.mgrsToLatLon("not a grid") == null, "garbage -> null");
    Test.assertMessage(Geo.mgrsToLatLon("99T WL 80740 04691") == null, "bad zone -> null");
    return true;
}
