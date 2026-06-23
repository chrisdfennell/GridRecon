# Changelog

All notable changes to GridRecon are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-06-23

### Added
- **Resection** — fix your own position with no GPS by sighting two known landmarks. For each, enter its grid (off your map) and the bearing you read to it (compass-sight or by hand); GridRecon intersects the two back-bearings and gives you where you stand — ready to navigate to or save as a mark. The classic map-and-compass position fix, and the headline reason the app keeps a compass-sight path. Backed by a spherical great-circle intersection (after Veness), unit-tested by round-tripping a known observer.
- **Grid → grid** — enter two MGRS grids and get the range and bearing between them (with the back-azimuth). The map-only calc — no GPS, no compass — for "how far is that saddle from this lake, and which way?". The second grid is seeded from the first, so you only dial the digits that differ.
- **Sunrise & sunset** — **Tools → Sun** shows today's sunrise, sunset and day length for your position, in local time, with polar-day / polar-night handling above the Arctic/Antarctic circles. Pure astronomy — no network, no extra permissions.
- **UTM coordinates** — **Tools → Settings → Coordinates** adds UTM (zone + band + full easting/northing) alongside MGRS and lat/long, for reading positions straight off a UTM-gridded topo map.
- **Elevation** — when the fix reports altitude, your elevation shows low on the home and "mark this spot" screens (down by the bottom arc, clear of the grid and the buttons), in metres or feet per your units setting.

## [1.3.0] - 2026-06-23

### Added
- **Find a target without GPS** — when there's no fresh fix, "Find a target" lets you enter your current position by grid (seeded from the last-known fix) and still computes the target's grid. This is the pure-geometry tool the "GPS off or jammed" premise is about — it no longer dead-ends when the receiver has nothing.
- **Sight a target with the compass** — "Find a target" can capture the bearing straight off the watch's magnetometer: aim the watch, press **SET**, then fine-tune on the spinner. It reads the compass while you're standing still (never the GPS course, which is your *direction of travel*, not where you're pointed) and falls back to manual entry on devices without a compass.
- **Mils** — **Tools → Settings → Bearings** switches bearing entry and display between degrees (0–359) and NATO mils (0–6399). Declination stays in degrees (that's how maps quote it).

### Fixed
- **Lat/long could overflow on small screens** — decimal lat/long now wraps to two lines instead of being clipped at the edges when it won't fit on one (the two-line fallback previously only handled the four-part MGRS shape).
- **Compass arrow trusted a possibly-bad heading** — the "Take me back" heading now uses the GPS course while you're moving (true-north and reliable) and falls back to the magnetometer only at a standstill, instead of always trusting the wrist compass — which could point confidently wrong and left the GPS path unused on compass devices.

### Changed
- **Spinner units render reliably** — the unit beside the big number ("mil", "m", "yd") is now drawn as a small label in a normal font, so it no longer depends on the NUMBER font happening to contain letters.

## [1.2.0] - 2026-06-22

### Added
- **Button-only input mode** — **Tools → Settings → Input** lets you choose "Buttons only", which ignores the touchscreen and switches the menus to a custom button-driven list (since native menus can't refuse touch). Defaults to "Touch + buttons".
- **Lat/long coordinates** — **Tools → Settings → Coordinates** toggles all displayed positions between MGRS and decimal lat/long.
- **Fully editable "Go to a grid"** — the zone, band and 100 km square are now editable too (not just the easting/northing), so you can navigate to a grid outside your current square.

### Fixed
- **"Mark this spot" saved a stale position** — because GPS powered down when you left the home screen for the menu, the fix could freeze at the spot where you opened the menu, so a mark made after walking off saved the *old* location (you had to return to the home screen to "reload" GPS first). "Mark this spot" now opens a live screen that keeps GPS on and shows your position updating as you move; SAVE captures the position at that moment. A fix that has gone stale (GPS stopped delivering for 30 s) is also no longer treated as fresh, so it can't be saved or used to compute a target as if it were current.

### Changed
- **Button hints redesigned** — each hint is now a short green arc on the bezel exactly at its physical button, with a small vector icon (menu / check / +/− / chevrons / back / save) instead of an inboard arrow and text word.
- **Clearer "no fix" guidance** — after ~20 s with no GPS, the home screen suggests going outside and checking the Location/GPS permission, rather than waiting indefinitely with no hint.

## [1.1.0] - 2026-06-21

### Added
- **Go to a grid** — punch in an MGRS grid you've been given and navigate to it (the inverse of "Find a target"). Entry is seeded from your current position, so you only dial the easting/northing digits. Backed by a new MGRS→lat/lon engine validated to the metre against MGRS/GEOTRANS.
- **Magnetic declination** — set your local offset once under **Tools → Settings → Declination** (East +, West −). Bearings you enter in "Find a target" are then taken as magnetic and converted to true for the grid math; "Take me back" shows the magnetic bearing to steer by. Magnetic bearings are marked with an `M`. Defaults to `0` (pure true north).
- **GPS fix quality & age** — the home screen shows fix quality (good / ok / poor / last-known) and flags a stale fix; "Mark this spot" and "Find a target" now require a fresh fix instead of silently computing off a cached last-known position.
- **Save a target as a mark** — from the "Find a target" result, press **UP** to save the computed target under a name and navigate back to it later.
- **Grid precision** — choose 1–5 grid figures (1 m up to 10 km) under **Tools → Settings → Grid precision**.
- **Units** — metric (m/km) or imperial (yd/mi) under **Tools → Settings → Units**, applied to every distance shown and entered.
- **Arrival vibration** — "Take me back" buzzes once when you reach the mark, so you don't have to be watching the screen.
- **Mark grids in the list** — "Manage marks" shows each mark's grid, so similarly-named marks can be told apart.
- **Unit tests** — automated suite for the geodesy/MGRS engine (both directions), declination math, grid precision, and the marks store (`source-test/`), run with `tools/runtests.ps1` and compile-checked in CI.

### Changed
- The "Take me back" compass arrow is now true-north referenced: the magnetic compass reading is declination-corrected, and the GPS course is only used to steer once you're actually moving (it's noise at a standstill). The magnetometer is also explicitly powered while navigating so the arrow has data on all devices.
- **GPS power** — the receiver now runs only while a position screen (home or navigation) is active, with a short grace period to avoid power-cycling, instead of being held for the whole session.

## [1.0.0] - 2026-06-21

First public release.

### Added
- **Live position** — current location shown as a fit-to-width MGRS grid.
- **Find a target** — enter a bearing + range to compute a target's MGRS grid and the back-azimuth; **navigate to it** with one button.
- **Mark this spot / Take me back** — save named marks (persisted across app restarts) and navigate back with a hybrid heading arrow, live distance, and bearing.
- **Manage marks** — review and delete saved marks with an on-device confirmation.
- **Geodesy engine** (`source/Geo.mc`) — WGS84 UTM→MGRS conversion plus spherical forward/inverse geodesics, validated to the metre against MGRS/GEOTRANS.
- **Responsive UI** — grids auto-shrink then break to two lines; verified from 280×280 down to a 156×156 monochrome Instinct 2S.
- **Button hints** — on-screen labels beside each physical button (START / BACK / UP / DOWN), and hold-to-repeat number entry.
- Targets fenix 8 Solar / tactix, fenix 7 family, Instinct 2/E/Crossover, and small Forerunners.
