<!-- Thanks for contributing to GridRecon! -->

## Description

<!-- What does this PR change and why? Link any related issue, e.g. "Closes #12". -->

## Type of change

- [ ] Bug fix
- [ ] New tool / feature (grid↔grid, resection, dead reckoning, etc.)
- [ ] Layout / readability improvement
- [ ] New device support
- [ ] Art / asset update
- [ ] Documentation
- [ ] Other:

## Devices tested

<!-- The Fenix 8 is the primary target; the Instinct 2S is the small/mono stress test. -->

- [ ] `fenix8solar51mm` (280×280, full colour)
- [ ] `instinct2s` (156×156, 1-bit monochrome)
- [ ] Other:

## Checklist

- [ ] `./build.ps1 -Device <device>` compiles with no warnings
- [ ] Verified in the simulator (`./build.ps1 -Device <device> -Run`)
- [ ] Grids stay legible (fit-to-width / two-line) with no clipping at the round edge or Instinct sub-window
- [ ] Colours survive monochrome (no green for must-read text)
- [ ] Handles a missing GPS fix / missing compass heading gracefully
- [ ] No test scaffolding left behind (e.g. a hardcoded position in `currentLatLon()`)
- [ ] Updated `CHANGELOG.md` for any user-facing change

## Screenshots

<!-- Before/after simulator screenshots for any visual change. -->
