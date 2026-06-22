# GridRecon — Connect IQ Store Listing

Store assets live in `assets/` (regenerate with `tools/gen_store_assets.py` and
`tools/gen_promo.py` — each is verified against the store's exact specs):
- `promo_banner.png` — 1440×720 hero image (≤ 2 MB)
- `cover_image.png` — 500×500 Web/Mobile cover (< 300 KB)
- `device_icon_24bit.png` — 128×128 device store icon, 24-bit colour
- `device_icon_64color.png` — 128×128 device store icon, reduced to 64 colours
- `icon_1024.png` — hi-res source of the launcher icon
- Screen images (280×280 native captures, < 150 KB each, via `tools/savescreenshot_scaled.ps1` run under **Windows PowerShell 5.1**):
  - `screen_main.png` — home / live MGRS
  - `screen_menu.png` — Tools menu
  - `screen_menu2.png` — "Mark as…" name picker
  - `screen_car.png` — Take me back (navigate to your car)

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

## What's new — v1.1.0
- **Go to a grid** — enter an MGRS grid and navigate straight to it (the inverse of Find-a-Target), seeded from your position so you only dial the digits that change.
- **Magnetic declination** — set your local offset once and enter the magnetic bearing your compass reads; the app converts to true.
- **GPS fix quality** — the home screen shows fix quality/age and the compute tools require a fresh fix.
- **Save a target as a mark**, **grid precision** (1 m–10 km), **metric/imperial units**, and an **arrival buzz** in Take-me-back.
- Smarter GPS power use and a true-north-referenced compass arrow.

## What's new — v1.0.0
First release: Find-a-Target grid computation, live MGRS position, hold-to-repeat
entry, and a responsive layout that scales across every supported screen.

## Permissions
- Positioning (GPS) — to show your current location.

## Notes for reviewers / accuracy
GridRecon uses GPS for *your* position. Its value is computing a *target's* grid
without needing a fix at the target. The fully GPS-denied tools (resection,
dead-reckoning) are roadmap items and are not claimed as present in v1.1.
