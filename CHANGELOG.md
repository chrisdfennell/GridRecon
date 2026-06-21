# Changelog

All notable changes to GridRecon are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
