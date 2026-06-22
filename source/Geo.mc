import Toybox.Lang;
import Toybox.Math;

//! Geodesy + MGRS engine for GridRecon.
//!
//! All math is done in Double precision (the UTM series involves numbers ~1e7,
//! which lose meter-level precision in 32-bit Float). WGS84 ellipsoid throughout.
//!
//! Two operations the firmware never exposes for hand computation:
//!   project()      - forward: from a point, go `dist` metres on bearing `az` -> new point
//!   latLonToMgrs() - convert a lat/lon to a standard MGRS grid string
//!
//! project() uses a spherical-earth model. Over tactical ranges (well under the
//! horizon) the spherical-vs-ellipsoid error is far smaller than the error in a
//! hand-read compass azimuth or a paced/lased range, so it is the right trade for
//! an MVP. Upgrade path is Vincenty-direct if we ever need survey accuracy.
module Geo {

    const PI = 3.141592653589793d;
    const DEG2RAD = PI / 180.0d;
    const RAD2DEG = 180.0d / PI;

    // Mean earth radius (metres) for the spherical forward solution.
    const R_EARTH = 6371000.0d;

    // WGS84 ellipsoid constants for UTM.
    const WGS_A  = 6378137.0d;                 // semi-major axis
    const WGS_F  = 1.0d / 298.257223563d;      // flattening

    //! Forward geodesic on a sphere.
    //! @param latDeg  start latitude  (degrees)
    //! @param lonDeg  start longitude (degrees)
    //! @param azDeg   bearing to travel, degrees true [0,360)
    //! @param distM   distance to travel, metres
    //! @return [destLatDeg, destLonDeg] as Array<Double>
    function project(latDeg as Double, lonDeg as Double, azDeg as Double, distM as Double) as Array<Double> {
        var lat1 = latDeg * DEG2RAD;
        var lon1 = lonDeg * DEG2RAD;
        var az   = azDeg  * DEG2RAD;
        var dR   = distM / R_EARTH;            // angular distance

        var sinLat1 = Math.sin(lat1);
        var cosLat1 = Math.cos(lat1);
        var sinDR   = Math.sin(dR);
        var cosDR   = Math.cos(dR);

        var sinLat2 = sinLat1 * cosDR + cosLat1 * sinDR * Math.cos(az);
        var lat2 = Math.asin(sinLat2);
        var lon2 = lon1 + Math.atan2(Math.sin(az) * sinDR * cosLat1,
                                     cosDR - sinLat1 * sinLat2);

        return [lat2 * RAD2DEG, lon2 * RAD2DEG] as Array<Double>;
    }

    //! Inverse geodesic on a sphere: distance and initial bearing from point 1 to
    //! point 2. Used by "Take me back" - how far and which way to a saved mark.
    //! @return [distanceMetres, bearingDegTrue] as Array<Double>
    function inverse(lat1 as Double, lon1 as Double, lat2 as Double, lon2 as Double) as Array<Double> {
        var p1   = lat1 * DEG2RAD;
        var p2   = lat2 * DEG2RAD;
        var dphi = (lat2 - lat1) * DEG2RAD;
        var dlam = (lon2 - lon1) * DEG2RAD;

        var sdp = Math.sin(dphi / 2.0d);
        var sdl = Math.sin(dlam / 2.0d);
        var a = sdp * sdp + Math.cos(p1) * Math.cos(p2) * sdl * sdl;
        var dist = R_EARTH * 2.0d * Math.atan2(Math.sqrt(a), Math.sqrt(1.0d - a));

        var y = Math.sin(dlam) * Math.cos(p2);
        var x = Math.cos(p1) * Math.sin(p2) - Math.sin(p1) * Math.cos(p2) * Math.cos(dlam);
        var brng = Math.atan2(y, x) * RAD2DEG;
        while (brng < 0.0d)    { brng += 360.0d; }
        while (brng >= 360.0d) { brng -= 360.0d; }

        return [dist, brng] as Array<Double>;
    }

    //! Back-azimuth of a bearing, normalised to [0,360).
    function backAzimuth(azDeg as Double) as Double {
        var b = azDeg + 180.0d;
        while (b >= 360.0d) { b -= 360.0d; }
        while (b < 0.0d)    { b += 360.0d; }
        return b;
    }

    //! Convert lat/lon (degrees, WGS84) to a full 1 m (10-figure) MGRS string,
    //! e.g. "18T WL 86441 14524".
    function latLonToMgrs(latDeg as Double, lonDeg as Double) as String {
        return mgrsAtPrecision(latDeg, lonDeg, 5);
    }

    //! As latLonToMgrs but showing `digits` easting/northing figures each (1..5):
    //! 5 = 1 m, 4 = 10 m, 3 = 100 m, 2 = 1 km, 1 = 10 km. Lower precision drops the
    //! least-significant digits (MGRS truncates, it doesn't round).
    //! Valid for latitudes -80..84 (the UTM/MGRS band). Outside that range the UPS
    //! grid would be required; we clamp and still return a best-effort string.
    function mgrsAtPrecision(latDeg as Double, lonDeg as Double, digits as Number) as String {
        if (digits < 1) { digits = 1; }
        if (digits > 5) { digits = 5; }

        // Normalise longitude to [-180,180).
        var lon = lonDeg;
        while (lon >= 180.0d) { lon -= 360.0d; }
        while (lon < -180.0d) { lon += 360.0d; }

        var lat = latDeg;
        if (lat > 84.0d)  { lat = 84.0d; }
        if (lat < -80.0d) { lat = -80.0d; }

        var zone = ((lon + 180.0d) / 6.0d).toNumber() + 1;   // 1..60
        if (zone > 60) { zone = 60; }
        if (zone < 1)  { zone = 1; }

        var utm = latLonToUtm(lat, lon, zone);
        var easting  = utm[0];
        var northing = utm[1];

        var bandLetter = latBand(lat);
        var squareId   = hundredKmSquare(zone, easting, northing);

        // Always compute the full 5 figures, then keep the leading `digits` of each.
        var eDigits = (easting.toLong() % 100000l).format("%05d").substring(0, digits);
        var nDigits = (northing.toLong() % 100000l).format("%05d").substring(0, digits);

        // Zone is conventionally zero-padded to two digits (e.g. "06V").
        return zone.format("%02d") + bandLetter + " " + squareId + " " + eDigits + " " + nDigits;
    }

    //! --- internals -------------------------------------------------------------

    //! UTM forward. Returns [easting, northing] in metres (Doubles).
    //! Northing carries the 10,000,000 m false northing in the southern hemisphere,
    //! which keeps the 100km-row lettering arithmetic correct.
    function latLonToUtm(latDeg as Double, lonDeg as Double, zone as Number) as Array<Double> {
        var k0 = 0.9996d;
        var a  = WGS_A;
        var e2  = WGS_F * (2.0d - WGS_F);       // first eccentricity squared
        var ep2 = e2 / (1.0d - e2);             // second eccentricity squared (e'^2)

        var latRad = latDeg * DEG2RAD;
        var lonRad = lonDeg * DEG2RAD;
        var lonOrigin = ((zone - 1) * 6 - 180 + 3).toDouble() * DEG2RAD;

        var sinLat = Math.sin(latRad);
        var cosLat = Math.cos(latRad);
        var tanLat = Math.tan(latRad);

        var N = a / Math.sqrt(1.0d - e2 * sinLat * sinLat);
        var T = tanLat * tanLat;
        var C = ep2 * cosLat * cosLat;
        var A = cosLat * (lonRad - lonOrigin);

        var e4 = e2 * e2;
        var e6 = e4 * e2;
        var M = a * (
            (1.0d - e2 / 4.0d - 3.0d * e4 / 64.0d - 5.0d * e6 / 256.0d) * latRad
            - (3.0d * e2 / 8.0d + 3.0d * e4 / 32.0d + 45.0d * e6 / 1024.0d) * Math.sin(2.0d * latRad)
            + (15.0d * e4 / 256.0d + 45.0d * e6 / 1024.0d) * Math.sin(4.0d * latRad)
            - (35.0d * e6 / 3072.0d) * Math.sin(6.0d * latRad));

        var A2 = A * A;
        var A3 = A2 * A;
        var A4 = A3 * A;
        var A5 = A4 * A;
        var A6 = A5 * A;

        var easting = k0 * N * (A + (1.0d - T + C) * A3 / 6.0d
            + (5.0d - 18.0d * T + T * T + 72.0d * C - 58.0d * ep2) * A5 / 120.0d) + 500000.0d;

        var northing = k0 * (M + N * tanLat * (A2 / 2.0d
            + (5.0d - T + 9.0d * C + 4.0d * C * C) * A4 / 24.0d
            + (61.0d - 58.0d * T + T * T + 600.0d * C - 330.0d * ep2) * A6 / 720.0d));

        if (latDeg < 0.0d) {
            northing += 10000000.0d;
        }

        return [easting, northing] as Array<Double>;
    }

    //! Latitude band letter (C..X, skipping I and O), 8-degree bands from -80.
    function latBand(latDeg as Double) as String {
        var bands = "CDEFGHJKLMNPQRSTUVWX";
        var idx = ((latDeg + 80.0d) / 8.0d).toNumber();
        if (idx < 0)  { idx = 0; }
        if (idx > 19) { idx = 19; }
        return bands.substring(idx, idx + 1);
    }

    //! --- inverse: MGRS -> lat/lon ----------------------------------------------

    //! Parse an MGRS string and return the [latDeg, lonDeg] of the cell's SW corner
    //! (the standard interpretation), or null if it isn't a parseable grid. Accepts
    //! the spaced form "18T WL 80740 04691" or the compact "18TWL8074004691", and
    //! any precision from 1 to 5 figures per axis (the easting/northing are scaled to
    //! metres accordingly). This is the inverse of latLonToMgrs / mgrsAtPrecision.
    function mgrsToLatLon(mgrs as String) as Array<Double>? {
        // Strip spaces.
        var s = "";
        for (var i = 0; i < mgrs.length(); i++) {
            var c = mgrs.substring(i, i + 1);
            if (!c.equals(" ")) { s += c; }
        }
        if (s.length() < 7) { return null; }   // need ZZBSQ + at least 1+1 digits

        var zone = s.substring(0, 2).toNumber();
        var band = s.substring(2, 3).toUpper();
        var colC = s.substring(3, 4).toUpper();
        var rowC = s.substring(4, 5).toUpper();
        var digits = s.substring(5, s.length());
        if (zone == null || zone < 1 || zone > 60) { return null; }

        var half = digits.length() / 2;
        if (half < 1 || half > 5 || half * 2 != digits.length()) { return null; }
        var eRaw = digits.substring(0, half).toNumber();
        var nRaw = digits.substring(half, half * 2).toNumber();
        if (eRaw == null || nRaw == null) { return null; }
        var scale = pow10(5 - half);                 // p-figure value -> metres
        var eMeters = eRaw * scale;
        var nMeters = nRaw * scale;

        // Easting from the column letter (set of 8 cycling every 3 zones).
        var set = zone % 3;
        var colLetters = (set == 1) ? "ABCDEFGH" : ((set == 2) ? "JKLMNPQR" : "STUVWXYZ");
        var colIdx = indexOfChar(colLetters, colC);
        if (colIdx < 0) { return null; }
        var easting = (colIdx + 1) * 100000 + eMeters;

        // Northing from the row letter, disambiguated by the latitude band.
        var rowLetters = "ABCDEFGHJKLMNPQRSTUV";
        var rowStrIdx = indexOfChar(rowLetters, rowC);
        if (rowStrIdx < 0) { return null; }
        var rowMod = rowStrIdx - ((zone % 2 == 0) ? 5 : 0);
        rowMod = ((rowMod % 20) + 20) % 20;

        var bands = "CDEFGHJKLMNPQRSTUVWX";
        var bandIdx = indexOfChar(bands, band);
        if (bandIdx < 0) { return null; }
        var south = bandIdx < 10;                    // bands C..M are southern
        var bandCenterLat = (-80 + bandIdx * 8 + 4).toDouble();
        var centralLon = ((zone - 1) * 6 - 180 + 3).toDouble();
        var approxN = latLonToUtm(bandCenterLat, centralLon, zone)[1];

        var base = (rowMod * 100000).toDouble() + nMeters;
        // Row letters repeat every 2,000,000 m; pick the cycle nearest the band.
        var cycles = roundD((approxN - base) / 2000000.0d);
        if (cycles < 0) { cycles = 0; }
        var northing = base + cycles.toDouble() * 2000000.0d;

        return utmToLatLon(easting.toDouble(), northing, zone, south);
    }

    //! UTM inverse (Snyder). [easting, northing] in metres + zone + hemisphere ->
    //! [latDeg, lonDeg]. `northing` carries the southern 10,000,000 m false northing.
    function utmToLatLon(easting as Double, northing as Double, zone as Number, south as Boolean) as Array<Double> {
        var k0 = 0.9996d;
        var a  = WGS_A;
        var e2  = WGS_F * (2.0d - WGS_F);
        var ep2 = e2 / (1.0d - e2);
        var e4 = e2 * e2;
        var e6 = e4 * e2;
        var e1 = (1.0d - Math.sqrt(1.0d - e2)) / (1.0d + Math.sqrt(1.0d - e2));

        var x = easting - 500000.0d;
        var y = south ? (northing - 10000000.0d) : northing;

        var M = y / k0;
        var mu = M / (a * (1.0d - e2 / 4.0d - 3.0d * e4 / 64.0d - 5.0d * e6 / 256.0d));

        var e1_2 = e1 * e1;
        var e1_3 = e1_2 * e1;
        var e1_4 = e1_3 * e1;
        var phi1 = mu
            + (3.0d * e1 / 2.0d - 27.0d * e1_3 / 32.0d) * Math.sin(2.0d * mu)
            + (21.0d * e1_2 / 16.0d - 55.0d * e1_4 / 32.0d) * Math.sin(4.0d * mu)
            + (151.0d * e1_3 / 96.0d) * Math.sin(6.0d * mu)
            + (1097.0d * e1_4 / 512.0d) * Math.sin(8.0d * mu);

        var sinP = Math.sin(phi1);
        var cosP = Math.cos(phi1);
        var tanP = Math.tan(phi1);
        var N1 = a / Math.sqrt(1.0d - e2 * sinP * sinP);
        var T1 = tanP * tanP;
        var C1 = ep2 * cosP * cosP;
        var R1 = a * (1.0d - e2) / Math.pow(1.0d - e2 * sinP * sinP, 1.5d);
        var D = x / (N1 * k0);

        var D2 = D * D;
        var D3 = D2 * D;
        var D4 = D3 * D;
        var D5 = D4 * D;
        var D6 = D5 * D;

        var lat = phi1 - (N1 * tanP / R1) * (D2 / 2.0d
            - (5.0d + 3.0d * T1 + 10.0d * C1 - 4.0d * C1 * C1 - 9.0d * ep2) * D4 / 24.0d
            + (61.0d + 90.0d * T1 + 298.0d * C1 + 45.0d * T1 * T1 - 252.0d * ep2 - 3.0d * C1 * C1) * D6 / 720.0d);

        var lon0 = ((zone - 1) * 6 - 180 + 3).toDouble() * DEG2RAD;
        var lon = lon0 + (D
            - (1.0d + 2.0d * T1 + C1) * D3 / 6.0d
            + (5.0d - 2.0d * C1 + 28.0d * T1 - 3.0d * C1 * C1 + 8.0d * ep2 + 24.0d * T1 * T1) * D5 / 120.0d) / cosP;

        return [lat * RAD2DEG, lon * RAD2DEG] as Array<Double>;
    }

    //! Index of a single character in a string, or -1 if absent.
    function indexOfChar(haystack as String, c as String) as Number {
        var idx = haystack.find(c);
        return (idx == null) ? -1 : idx;
    }

    //! 10^n for small non-negative n (n in 0..5 here).
    function pow10(n as Number) as Number {
        var p = 1;
        for (var i = 0; i < n; i++) { p *= 10; }
        return p;
    }

    //! Round a Double to the nearest integer (half away from zero).
    function roundD(x as Double) as Number {
        return ((x >= 0.0d) ? (x + 0.5d) : (x - 0.5d)).toNumber();
    }

    //! Two-letter 100,000 m square identifier (column letter + row letter).
    function hundredKmSquare(zone as Number, easting as Double, northing as Double) as String {
        var col = (easting / 100000.0d).toNumber();    // 1..8
        if (col < 1) { col = 1; }
        if (col > 8) { col = 8; }

        // Column letters cycle through three sets every 3 zones (I and O omitted).
        var set = zone % 3;
        var colLetters;
        if (set == 1) {
            colLetters = "ABCDEFGH";
        } else if (set == 2) {
            colLetters = "JKLMNPQR";
        } else {
            colLetters = "STUVWXYZ";
        }
        var colChar = colLetters.substring(col - 1, col);

        // Row letters: A..V (20 letters, I/O omitted). Even zones are offset by 5.
        var rowLetters = "ABCDEFGHJKLMNPQRSTUV";
        var rowIdx = (northing / 100000.0d).toNumber();
        if (zone % 2 == 0) {
            rowIdx += 5;
        }
        rowIdx = rowIdx % 20;
        if (rowIdx < 0) { rowIdx += 20; }
        var rowChar = rowLetters.substring(rowIdx, rowIdx + 1);

        return colChar + rowChar;
    }
}
