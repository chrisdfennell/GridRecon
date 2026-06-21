# GridRecon — Connect IQ Store Listing

Assets live in `assets/`:
- `icon_1024.png` — app/store icon (source; the 40px launcher is in resources)
- `promo_banner.png` — 1280×640 marketing banner (the feature chips include roadmap items)
- Device screenshots — capture from the simulator (home / Find-a-target / result)

---

## App name
GridRecon

## Type
Watch App

## Category
Utilities (Navigation / Tools)

## Short description (one line)
Turn a bearing and a distance into a target's map grid — and see your own live MGRS.

## Description (long)

**GridRecon is a land-navigation computer for your wrist.** It does the map-and-
compass math your watch's built-in nav doesn't: point at something, read its
bearing and range, and GridRecon gives you that thing's exact MGRS grid — ready
to call in, mark, or navigate to. No need for GPS *at the target*.

**In this release**
- **Find a target** — enter the bearing and distance to any point you can see and
  get its MGRS grid, plus the back-azimuth to walk yourself home.
- **Live position** — your current location shown as a clean MGRS grid, auto-sized
  to your screen.
- **Built for buttons** — hold UP/DOWN to fly through values; no fiddly tapping.
- **Runs everywhere** — one app, legible from a 280×280 fenix down to a 156×156
  Instinct, including monochrome displays.

**Who it's for**
Hunters, search-and-rescue, military and competitive land-nav, backcountry
travelers — anyone who thinks in grids and bearings.

**On the roadmap**
Grid-to-grid range & bearing, resection (fix your position from two bearings),
dead-reckoning leg navigation, and a digital pace count — the tools you fall back
on when GPS is jammed, off, or unavailable.

## Supported devices
fenix 8 / 8 Solar, tactix, fenix 7 / 7S / 7X (Pro), fenix 6S, epix,
Forerunner 255S / 55, Instinct 2 / 2S / 2X / E / Crossover.

## Tags / keywords
land nav, MGRS, UTM, grid, bearing, azimuth, compass, navigation, tactical,
hunting, SAR, military, backcountry, call for fire, target

## What's new — v1.0.0
First release: Find-a-Target grid computation, live MGRS position, hold-to-repeat
entry, and a responsive layout that scales across every supported screen.

## Permissions
- Positioning (GPS) — to show your current location.

## Notes for reviewers / accuracy
GridRecon uses GPS for *your* position. Its value is computing a *target's* grid
without needing a fix at the target. The fully GPS-denied tools (resection,
dead-reckoning) are roadmap items and are not claimed as present in v1.0.
