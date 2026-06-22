param(
    # Device to run the test suite on. The Geo math is device-independent, so the
    # default primary target is fine; override only if you want to spot-check another.
    [string]$Device = "fenix8solar51mm"
)

# Runs the GridRecon unit-test suite (source-test/*.mc) in the Connect IQ
# simulator and prints PASS/FAIL per test. Mirrors build.ps1's toolchain
# resolution so it works with the same git-ignored build_config.json.

$root = Split-Path $PSScriptRoot   # repo root (tools/ -> ..)

# --- Resolve toolchain paths (build_config.json -> auto-detect) ---------------
$configFile = Join-Path $root "build_config.json"
$JavaHome = $null
$SdkDir = $null
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
    $JavaHome = $config.JavaHome
    $SdkDir = $config.SdkDir
}
if (-not $SdkDir) {
    $sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
    if (Test-Path $sdkRoot) {
        $latest = Get-ChildItem $sdkRoot -Directory -ErrorAction SilentlyContinue |
                  Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $SdkDir = $latest.FullName }
    }
}
if (-not $JavaHome) {
    if ($env:JAVA_HOME) {
        $JavaHome = $env:JAVA_HOME
    } else {
        $java = Get-Command java -ErrorAction SilentlyContinue
        if ($java) { $JavaHome = Split-Path (Split-Path $java.Source) }
    }
}
if (-not $SdkDir -or -not (Test-Path $SdkDir)) {
    Write-Error "Connect IQ SDK not found. Install it, or set SdkDir in build_config.json."
    exit 1
}
if (-not $JavaHome) {
    Write-Error "Java not found. Set JAVA_HOME, or set JavaHome in build_config.json."
    exit 1
}

# --- Environment --------------------------------------------------------------
$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH
$sdkBin   = Join-Path $SdkDir "bin"
$monkeyc  = Join-Path $sdkBin "monkeyc.bat"
$monkeydo = Join-Path $sdkBin "monkeydo.bat"
$jungle   = Join-Path $root "monkey-test.jungle"
$key      = Join-Path $root "developer_key.der"

if (-not (Test-Path $key)) {
    Write-Error "Missing developer_key.der in the repo root. See CONTRIBUTING.md to generate one."
    exit 1
}
if (-not (Test-Path (Join-Path $root "bin"))) { New-Item -ItemType Directory -Path (Join-Path $root "bin") | Out-Null }

# --- Build the test binary (-t links in the test runner) ----------------------
$output = Join-Path $root "bin\GridRecon_test.prg"
Write-Host "Building test suite for $Device..." -ForegroundColor Cyan
& $monkeyc -t -f $jungle -o $output -y $key -d $Device -w
if ($LASTEXITCODE -ne 0) { Write-Error "Test compilation failed ($LASTEXITCODE)."; exit $LASTEXITCODE }

# --- Run the tests in the simulator -------------------------------------------
# monkeydo only CONNECTS to a running simulator, so start one first if needed.
if (-not (Get-Process -Name simulator -ErrorAction SilentlyContinue)) {
    Write-Host "Starting the Connect IQ simulator..." -ForegroundColor Cyan
    Start-Process (Join-Path $sdkBin "simulator.exe")
    Start-Sleep -Seconds 6
}
Write-Host "Running unit tests..." -ForegroundColor Cyan
& $monkeydo $output $Device /t
