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

    //! Convert lat/lon (degrees, WGS84) to an MGRS string, e.g. "18T WL 86441 14524".
    //! Valid for latitudes -80..84 (the UTM/MGRS band). Outside that range the UPS
    //! grid would be required; we clamp and still return a best-effort string.
    function latLonToMgrs(latDeg as Double, lonDeg as Double) as String {
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

        var eDigits = (easting.toLong() % 100000l).format("%05d");
        var nDigits = (northing.toLong() % 100000l).format("%05d");

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
