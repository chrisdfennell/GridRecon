param(
    # Primary target. Other supported ids live in manifest.xml (Instinct, FR55, etc.).
    [string]$Device = "fenix8solar51mm",
    [switch]$Run,
    [switch]$Export
)

# --- Resolve toolchain paths --------------------------------------------------
# Order of preference: build_config.json (your local overrides, git-ignored) ->
# auto-detected SDK / Java. Nothing machine-specific is committed.
$configFile = Join-Path $PSScriptRoot "build_config.json"
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

# Persist whatever we resolved so it's easy to tweak next time (git-ignored).
if (-not (Test-Path $configFile)) {
    [ordered]@{ JavaHome = $JavaHome; SdkDir = $SdkDir } | ConvertTo-Json | Out-File -Encoding utf8 $configFile
}

# --- Environment --------------------------------------------------------------
$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH
$sdkBin = Join-Path $SdkDir "bin"
$monkeyc = Join-Path $sdkBin "monkeyc.bat"
$jungle = Join-Path $PSScriptRoot "monkey.jungle"
$key = Join-Path $PSScriptRoot "developer_key.der"

if (-not (Test-Path $key)) {
    Write-Error "Missing developer_key.der in the repo root. See CONTRIBUTING.md to generate one."
    exit 1
}
if (-not (Test-Path "bin")) { New-Item -ItemType Directory -Path "bin" | Out-Null }

# --- Build --------------------------------------------------------------------
if ($Export) {
    Write-Host "Packaging GridRecon for the Connect IQ Store (.iq)..." -ForegroundColor Cyan
    $output = Join-Path $PSScriptRoot "bin\GridRecon.iq"
    & $monkeyc -e -f $jungle -o $output -y $key -w
} else {
    Write-Host "Building GridRecon for $Device..." -ForegroundColor Cyan
    $output = Join-Path $PSScriptRoot "bin\GridRecon.prg"
    & $monkeyc -f $jungle -o $output -y $key -d $Device -w
}
if ($LASTEXITCODE -ne 0) { Write-Error "Compilation failed ($LASTEXITCODE)."; exit $LASTEXITCODE }
Write-Host "Build succeeded: $output" -ForegroundColor Green

# --- Run in the simulator -----------------------------------------------------
# monkeydo only CONNECTS to a running simulator, so start one first if needed.
if ($Run) {
    if (-not (Get-Process -Name simulator -ErrorAction SilentlyContinue)) {
        Write-Host "Starting the Connect IQ simulator..." -ForegroundColor Cyan
        Start-Process (Join-Path $sdkBin "simulator.exe")
        Start-Sleep -Seconds 6
    } else {
        Write-Host "Simulator already running." -ForegroundColor Cyan
    }
    Write-Host "Loading GridRecon into the simulator..." -ForegroundColor Cyan
    & (Join-Path $sdkBin "monkeydo.bat") $output $Device
}
