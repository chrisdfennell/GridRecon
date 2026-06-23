import Toybox.Lang;
import Toybox.Test;

//! Tests for the declination offset math in Settings. Pure given the stored value,
//! but the sign convention (East +) and the 360deg wrap are easy to get backwards,
//! so they're pinned here. (nearD lives in GeoTest.mc; both are compiled together.)
//!
//! These mutate the persisted declination, so each test restores it before returning.

(:test)
function testDeclinationConversion(logger as Test.Logger) as Boolean {
    var saved = Settings.declination();

    // East declination: true = magnetic + decl.
    Settings.setDeclination(13);
    Test.assertMessage(nearD(Settings.magToTrue(45.0d), 58.0d, 1.0e-9d), "E mag->true");
    Test.assertMessage(nearD(Settings.trueToMag(58.0d), 45.0d, 1.0e-9d), "E true->mag");

    // West declination is negative.
    Settings.setDeclination(-7);
    Test.assertMessage(nearD(Settings.magToTrue(10.0d), 3.0d, 1.0e-9d), "W mag->true");
    Test.assertMessage(nearD(Settings.trueToMag(3.0d), 10.0d, 1.0e-9d), "W true->mag");

    // Zero offset is the identity.
    Settings.setDeclination(0);
    Test.assertMessage(nearD(Settings.magToTrue(123.0d), 123.0d, 1.0e-9d), "identity");
    Test.assertMessage(!Settings.hasDeclination(), "hasDeclination false at 0");

    Settings.setDeclination(saved);
    return true;
}

//! Conversions must stay in [0,360): adding/subtracting past the seam wraps.
(:test)
function testDeclinationWrap(logger as Test.Logger) as Boolean {
    var saved = Settings.declination();

    Settings.setDeclination(10);
    Test.assertMessage(nearD(Settings.magToTrue(355.0d), 5.0d, 1.0e-9d), "wrap over 360"); // 365 -> 5

    Settings.setDeclination(-15);
    Test.assertMessage(nearD(Settings.magToTrue(5.0d), 350.0d, 1.0e-9d), "wrap under 0");  // -10 -> 350
    Test.assertMessage(nearD(Settings.trueToMag(355.0d), 10.0d, 1.0e-9d), "true->mag wrap"); // 355-(-15)=370->10

    Settings.setDeclination(saved);
    return true;
}

//! The menu/confirmation label reads naturally with the East/West suffix.
(:test)
function testDeclinationLabel(logger as Test.Logger) as Boolean {
    var saved = Settings.declination();

    Settings.setDeclination(13);
    Test.assertMessage(Settings.declLabel().equals("13° E"), "east label: " + Settings.declLabel());
    Settings.setDeclination(-6);
    Test.assertMessage(Settings.declLabel().equals("6° W"), "west label: " + Settings.declLabel());
    Settings.setDeclination(0);
    Test.assertMessage(Settings.declLabel().equals("off (true north)"), "off label: " + Settings.declLabel());

    Settings.setDeclination(saved);
    return true;
}

//! Grid precision setting: label maps digits to ground resolution; reads are clamped.
(:test)
function testGridDigitsSetting(logger as Test.Logger) as Boolean {
    var saved = Settings.gridDigits();

    Settings.setGridDigits(3);
    Test.assertMessage(Settings.gridDigits() == 3, "set 3");
    Test.assertMessage(Settings.gridLabel().equals("3 (100 m)"), "label: " + Settings.gridLabel());
    Settings.setGridDigits(5);
    Test.assertMessage(Settings.gridLabel().equals("5 (1 m)"), "label: " + Settings.gridLabel());
    Settings.setGridDigits(1);
    Test.assertMessage(Settings.gridLabel().equals("1 (10 km)"), "label: " + Settings.gridLabel());

    Settings.setGridDigits(9);
    Test.assertMessage(Settings.gridDigits() == 5, "clamp high on read");
    Settings.setGridDigits(0);
    Test.assertMessage(Settings.gridDigits() == 1, "clamp low on read");

    Settings.setGridDigits(saved);
    return true;
}

//! Units setting round-trips and labels correctly.
(:test)
function testUnitsSetting(logger as Test.Logger) as Boolean {
    var saved = Settings.useImperial();

    Settings.setUseImperial(true);
    Test.assertMessage(Settings.useImperial(), "imperial on");
    Test.assertMessage(Settings.unitsLabel().equals("Imperial (yd/mi)"), "label: " + Settings.unitsLabel());
    Settings.setUseImperial(false);
    Test.assertMessage(!Settings.useImperial(), "metric on");
    Test.assertMessage(Settings.unitsLabel().equals("Metric (m/km)"), "label: " + Settings.unitsLabel());

    Settings.setUseImperial(saved);
    return true;
}

//! Bearing angle unit: the degrees<->mils conversions round-trip and the display
//! formatter pads and tags (magnetic "M") correctly in each unit.
(:test)
function testBearingUnits(logger as Test.Logger) as Boolean {
    var saved = Settings.useMils();

    // Degrees: identity conversions, 3-figure pad, "°" with optional "M".
    Settings.setUseMils(false);
    Test.assertMessage(Settings.angleLabel().equals("Degrees (0–359)"), "deg label: " + Settings.angleLabel());
    Test.assertMessage(Settings.bearingMax() == 359, "deg max");
    Test.assertMessage(nearD(Settings.bearingToDegrees(58), 58.0d, 1.0e-9d), "deg->deg");
    Test.assertMessage(Settings.bearingFromDegrees(58.0d) == 58, "deg from deg");
    Test.assertMessage(Settings.formatBearing(58.0d, false).equals("058°"), "deg fmt true: " + Settings.formatBearing(58.0d, false));
    Test.assertMessage(Settings.formatBearing(58.0d, true).equals("058°M"), "deg fmt mag: " + Settings.formatBearing(58.0d, true));

    // Mils: 90° == 1600 mils, 4-figure pad, " mil" with optional "M".
    Settings.setUseMils(true);
    Test.assertMessage(Settings.bearingMax() == 6399, "mil max");
    Test.assertMessage(Settings.bearingFromDegrees(90.0d) == 1600, "90deg -> 1600mil");
    Test.assertMessage(nearD(Settings.bearingToDegrees(1600), 90.0d, 1.0e-9d), "1600mil -> 90deg");
    Test.assertMessage(Settings.formatBearing(90.0d, false).equals("1600 mil"), "mil fmt true: " + Settings.formatBearing(90.0d, false));
    Test.assertMessage(Settings.formatBearing(90.0d, true).equals("1600 milM"), "mil fmt mag: " + Settings.formatBearing(90.0d, true));
    // Wrap: a full turn normalises back to zero in both directions.
    Test.assertMessage(Settings.bearingFromDegrees(360.0d) == 0, "360deg -> 0mil");

    Settings.setUseMils(saved);
    return true;
}
