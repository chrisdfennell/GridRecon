# Contributing to GridRecon

Thanks for your interest in improving GridRecon — a GPS-denied land-navigation
toolkit for Garmin watches, written in [Monkey C](https://developer.garmin.com/connect-iq/monkey-c/).
Contributions of all kinds are welcome: bug reports, new tools, device support,
layout/readability fixes, and documentation.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** — open a [bug report](../../issues/new?template=bug_report.yml). Include your device, firmware, and SDK version.
- **Request a feature** — open a [feature request](../../issues/new?template=feature_request.yml). The [roadmap](README.md#️-roadmap) is a good place to start.
- **Submit a change** — fork, branch, and open a pull request (see below).

## Development setup

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) **9.x+** (install the Fenix 8 / Instinct device profiles via the **SDK / Device Manager**).
- **Java 17+** (Java 21 recommended).
- **PowerShell** (the build script is PowerShell-based).
- **Python 3 + Pillow** — only if you regenerate the icon or promo art (`pip install pillow`).
- A Connect IQ **developer key** (`developer_key.der`) in the repo root. Generate one with:
  ```powershell
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
  ```
  This file is git-ignored and must **never** be committed.

### Build & run

```powershell
.\build.ps1                       # build for fenix8solar51mm
.\build.ps1 -Device instinct2s    # build a different device
.\build.ps1 -Run                  # build, start the simulator if needed, and load
.\build.ps1 -Export               # package a store-ready .iq
```

`build.ps1` auto-detects your SDK and JDK and writes a git-ignored `build_config.json`.
Edit it if you need to pin a specific SDK or JDK path.

> The Connect IQ simulator must be **running** before an app can be loaded —
> `monkeydo` only connects to it. `build.ps1 -Run` starts one for you if needed; if
> you use the extension's F5 and it hangs, it usually means no simulator is open.

## Project layout

- `source/Geo.mc` — the geodesy + MGRS engine (UTM forward, spherical project/inverse). The one piece with real algorithm work; keep it covered.
- `source/Views.mc` — home + result screens.
- `source/Nav.mc` — live "Take me back" navigation (arrow + distance + bearing).
- `source/NumberInput.mc` — the hold-to-repeat number spinner.
- `source/ToolMenu.mc` — the tools menu and its flows (find target, mark, manage).
- `source/Marks.mc` — persistent saved marks (`Application.Storage`).
- `source/Draw.mc` — shared drawing: fit-to-width grid text, button hints.
- `resources/` — strings + launcher icon. `tools/` — icon/promo generators.

## Testing your changes

### Unit tests (the Geo engine)

The geodesy + MGRS math in `source/Geo.mc` is pinned by an automated suite in
`source-test/GeoTest.mc` — golden MGRS strings from the GEOTRANS-backed Python
`mgrs` library, plus `project()`/`inverse()` round-trips. Run it in the simulator:

```powershell
.\tools\runtests.ps1                     # build the -t target and run all tests
.\tools\runtests.ps1 -Device instinct2s  # run on another device (math is device-independent)
```

The tests live in `source-test/` and are pulled in only by `monkey-test.jungle`
(via the `-t` flag), so they never ship in a production build. CI compiles this
target to keep the suite from breaking; execution is local because it needs the
GUI simulator. **If you touch `Geo.mc`, add or update a case here.**

### On-device / layout checks

GridRecon targets the **Fenix 8 Solar 51mm** primarily, but the small/monochrome
**Instinct 2S** is the layout stress test. Please verify on both:

- `fenix8solar51mm` (280×280, full colour)
- `instinct2s` (156×156, 1-bit monochrome, has a carved-out sub-window)

Things to check in the simulator:

- Grids fit and stay legible (the fit-to-width / two-line fallback) — no clipping at the round edge or under the Instinct sub-window.
- Colours survive monochrome: bright foreground colours (white / yellow) are safe; **green maps to the background on 1-bit panels and disappears** — don't use it for anything that must be read.
- Button hints line up with the right physical buttons.
- For a position-dependent screen, the simulator has no simple lat/lon entry — temporarily return a fixed coordinate from `currentLatLon()` to test, and revert before committing.

## Coding guidelines

- Match the existing style: 4-space indentation, explicit type annotations on method signatures, `private var` for fields.
- Do geodesy in **`Double`** precision — the UTM series loses metre-level accuracy in 32-bit `Float`.
- Lay everything out relative to `dc.getWidth()/getHeight()`; draw grids via `drawButtonHint` / the fit-to-width helper rather than hard-coded coordinates, so it holds across the device range.
- Guard optional APIs with `has` checks and handle `null` (no GPS fix, no compass heading) gracefully.
- Never commit test scaffolding (e.g. a hardcoded position fallback) — verify the source is clean before opening a PR.

## Pull request process

1. Fork and branch off `main` (e.g. `feature/grid-to-grid` or `fix/spinner-overlap`).
2. Confirm it **builds clean** (`.\build.ps1` with no warnings) and runs in the simulator. If you touched `Geo.mc`, run `.\tools\runtests.ps1` and make sure the suite is green.
3. Fill out the PR template — devices tested, and before/after screenshots for any visual change.
4. Keep PRs focused — one logical change each.
5. Update `CHANGELOG.md` for user-facing changes.

### Commit messages

Short, imperative summaries, optionally with [Conventional Commits](https://www.conventionalcommits.org/) prefixes:

```
feat: add grid-to-grid range & bearing
fix: stop the bearing prompt overlapping the START hint
docs: document the true-north declination caveat
```

Thanks for contributing!
