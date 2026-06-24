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
  - `screen_settings.png` — Settings list: input / coordinates / bearings / declination / grid / units **(re-capture for v1.3: now includes Bearings)**
  - `screen_sight.png` — "Point at target" compass bearing capture **(new for v1.3)**
  - `screen_position.png` — set your position by grid when there's no GPS fix **(new for v1.3)**
  - `screen_resection.png` — Resection result: your computed position as a grid **(new for v1.4)**
  - `screen_sun.png` — Sun: sunrise / sunset / day length **(new for v1.4)**
  - `screen_main.png` re-capture for v1.4 also shows the elevation line; `screen_menu.png` re-capture now includes "Grid → grid", "Resection" and "Sun"

---

## App name
GridRecon

## Type
Watch App

## Category
Utilities (Navigation / Tools)

## Short description (one line)
Backcountry map-and-compass tools: get the grid of any spot you can see, navigate to a grid, and mark camp, the car, or a trailhead.

## Description (long)

**GridRecon is a map-and-compass computer for your wrist.** Spot a peak, a lake, or
a campsite across the valley, sight its bearing and judge the distance, and
GridRecon gives you that spot's exact grid coordinates — ready to mark, share with
your group, or navigate to. No GPS fix needed *at the spot itself*.

**What it does**
- **Find a target** — sight the bearing to any landmark you can see (a summit, a
  saddle, the far shore of a lake) and add the distance; GridRecon gives you its
  grid plus the bearing back to where you're standing. No GPS fix? Enter your own
  position by grid and it still works.
- **Go to a grid** — punch in a grid a friend gave you, or one you read off your
  topo map, and navigate straight to it; it's seeded from your position, so you
  only dial the digits that change.
- **Resection** — no GPS? Fix your *own* position the old-fashioned way: sight two
  known landmarks, enter each one's grid and the bearing to it, and GridRecon
  crosses the back-bearings to put you on the map.
- **Grid → grid** — enter two grids and get the range and bearing between them; the
  map-only calc for "how far is that saddle, and which way?".
- **Mark this spot / Take me back** — save named marks (Camp, Car, Trailhead,
  Water…) and navigate back with a heading arrow, live distance, and a buzz on
  arrival.
- **Live position** — your current location as a clean grid, auto-sized to your
  screen, with a GPS fix-quality indicator and your elevation so you know you can
  trust it — handy to read straight onto a paper map.
- **Sunrise & sunset** — today's sun times and day length for where you are, in
  local time, so you know how much daylight is left.
- **Magnetic declination** — set your local offset once and enter the magnetic
  bearing your compass actually reads; GridRecon converts to true north.
- **Your settings** — MGRS, lat/long or UTM, bearings in degrees or mils, grid
  precision (1 m to 10 km), metric or imperial units, and a buttons-only mode.
- **Built for buttons** — hold UP/DOWN to fly through values; works with gloves on,
  no fiddly tapping.
- **Runs everywhere** — one app, legible from a 280×280 fenix down to a 156×156
  Instinct, including monochrome displays.

**Who it's for**
Hikers, backpackers, campers, hunters, anglers, and backcountry travelers — anyone
who navigates with a map and compass and thinks in grid coordinates.

**On the roadmap**
Dead-reckoning leg navigation and a digital pace count — classic land-nav skills for
when GPS is unreliable under heavy tree canopy or in deep canyons, your battery's
running low, or you just want to navigate the old-fashioned way.

## Supported devices
fenix 8 / 8 Solar, tactix, fenix 7 / 7S / 7X (Pro), fenix 6S, epix,
Forerunner 255S / 55, Instinct 2 / 2S / 2X / E / Crossover.

## Tags / keywords
hiking, backpacking, camping, backcountry, land nav, map and compass, MGRS, UTM,
USNG, topo, grid, bearing, azimuth, compass, navigation, orienteering, hunting, trail

## What's new — v1.4.1
- **Compass** — Tools → Compass: a live heading dial (rotating card, cardinals, big readout) that works with GPS off.
- **Steadier "Take me back" arrow** — it now holds your GPS heading through brief pauses instead of jumping to the wrist compass.

## What's new — v1.4.0
- **Resection** — fix your own position with no GPS: sight two known landmarks, enter each one's grid and bearing, and GridRecon crosses the back-bearings to put you on the map. Save the result as a mark.
- **Grid → grid** — enter two grids and get the range and bearing between them (and the back-azimuth).
- **Sunrise & sunset** — Tools → Sun shows today's sun times and day length for your position, in local time (polar day/night aware).
- **UTM coordinates** — read positions as UTM (zone + easting/northing) alongside MGRS and lat/long (Settings → Coordinates).
- **Elevation** — your altitude now shows on the home and "mark this spot" screens when the fix reports it.

## What's new — v1.3.0
- **Find a target without a GPS fix** — no signal under the trees? Enter your position by grid (seeded from your last-known fix) and still get the spot's grid.
- **Sight with the compass** — point the watch at a landmark, press SET, and the bearing is captured from the compass; fine-tune it on the spinner.
- **Mils** — enter and read bearings in mils (0–6399) instead of degrees (Settings → Bearings).

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
GridRecon uses GPS for *your* position. Its value is computing the grid of a distant
point you can see without needing a fix there — and, as of v1.3, "Find a target" can
run with no fix at all by entering your own position by grid. As of v1.4, **resection**
recovers your own position from two landmark bearings with no GPS fix at all (a
spherical great-circle intersection; accuracy depends on the quality of your bearings
and a good ~30–150° cut between the landmarks). The remaining off-the-grid tools
(dead-reckoning, pace count) are roadmap items and are not claimed as present in v1.4.
Sunrise/sunset uses the standard low-precision sun equation (good to ~1 minute).
