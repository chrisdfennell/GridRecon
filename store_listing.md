# GridRecon — Connect IQ Store Listing

Store assets live in `assets/` (regenerate with `tools/gen_store_assets.py` and
`tools/gen_promo.py` — each is verified against the store's exact specs):
- `promo_banner.png` — 1440×720 hero image (≤ 2 MB)
- `cover_image.png` — 500×500 Web/Mobile cover (< 300 KB)
- `device_icon_24bit.png` — 128×128 device store icon, 24-bit colour
- `device_icon_64color.png` — 128×128 device store icon, reduced to 64 colours
- `icon_1024.png` — hi-res source of the launcher icon
- Screen images (280×280 native captures, < 150 KB each, via `tools/savescreenshot_scaled.ps1` run under **Windows PowerShell 5.1** — it uses `System.Drawing`, which PowerShell 7 doesn't expose; the script auto-detects display scaling):
  - `screen_main.png` — home / live MGRS **(re-capture for v1.1: now shows the GPS fix-quality line)**
  - `screen_menu.png` — Tools menu **(re-capture for v1.1: now includes "Go to a grid" and "Settings")**
  - `screen_menu2.png` — "Mark as…" name picker
  - `screen_car.png` — Take me back (navigate to your car)
  - `screen_grid.png` — Go to a grid (digit entry) **(new for v1.1)**
  - `screen_settings.png` — Settings: declination / grid precision / units **(new for v1.1)**

---

## App name
GridRecon

## Type
Watch App

## Category
Utilities (Navigation / Tools)

## Short description (one line)
Compute a target's MGRS grid from a bearing and range, navigate to any grid, and mark your spots — GPS-denied land nav.

## Description (long)

**GridRecon is a land-navigation computer for your wrist.** It does the map-and-
compass math your watch's built-in nav doesn't: point at something, read its
bearing and range, and GridRecon gives you that thing's exact MGRS grid — ready
to call in, mark, or navigate to. No need for GPS *at the target*.

**What it does**
- **Find a target** — enter the bearing and distance to any point you can see and
  get its MGRS grid, plus the back-azimuth to walk yourself home.
- **Go to a grid** — punch in an MGRS grid you've been given and navigate straight
  to it; seeded from your position, so you only dial the digits that change.
- **Mark this spot / Take me back** — save named marks (Car, Camp, Trailhead…) and
  navigate back with a heading arrow, live distance, and a buzz on arrival.
- **Live position** — your current location as a clean MGRS grid, auto-sized to
  your screen, with a GPS fix-quality indicator so you know it's trustworthy.
- **Magnetic declination** — set your local offset once and enter the magnetic
  bearing your compass actually reads; GridRecon converts to true north.
- **Your settings** — grid precision (1 m to 10 km) and metric or imperial units.
- **Built for buttons** — hold UP/DOWN to fly through values; no fiddly tapping.
- **Runs everywhere** — one app, legible from a 280×280 fenix down to a 156×156
  Instinct, including monochrome displays.

**Who it's for**
Hunters, search-and-rescue, military and competitive land-nav, backcountry
travelers — anyone who thinks in grids and bearings.

**On the roadmap**
Resection (fix your position from two bearings), dead-reckoning leg navigation,
and a digital pace count — the tools you fall back on when GPS is jammed, off, or
unavailable.

## Supported devices
fenix 8 / 8 Solar, tactix, fenix 7 / 7S / 7X (Pro), fenix 6S, epix,
Forerunner 255S / 55, Instinct 2 / 2S / 2X / E / Crossover.

## Tags / keywords
land nav, MGRS, UTM, grid, bearing, azimuth, compass, navigation, tactical,
hunting, SAR, military, backcountry, call for fire, target

## What's new — v1.2.0
- **Fixed: "Mark this spot" could save a stale position** — marking now opens a live screen that keeps GPS on and shows your position as you move, so the saved mark is where you are *now* (no need to reopen the home screen to "reload" GPS first).
- **Buttons-only input mode** — ignore the touchscreen and drive everything with the buttons (Settings → Input).
- **Lat/long coordinates** — show positions as decimal lat/long instead of MGRS (Settings → Coordinates).
- **Fully editable "Go to a grid"** — the zone, band and 100 km square are editable too, so you can navigate to a grid outside your current square.
- **Redesigned button hints** — a green arc with a vector icon sits exactly at each physical button.

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
- Positioning (GPS) — to show your current location and navigate to marks/grids.
- Sensor — to read the compass heading for the "Take me back" navigation arrow.

## Notes for reviewers / accuracy
GridRecon uses GPS for *your* position. Its value is computing a *target's* grid
without needing a fix at the target. The fully GPS-denied tools (resection,
dead-reckoning) are roadmap items and are not claimed as present in v1.2.
