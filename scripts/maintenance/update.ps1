# Update cc-install (Windows).
#
# Two things get updated, which is the whole point:
#   1. The cc-install files themselves (launchers, docs, Dockerfile, VERSION).
#      The old version skipped this, so bug fixes in the scripts could never
#      reach anyone who had already installed.
#   2. The Docker image, rebuilt from scratch so Claude Code and code-server
#      come down at their latest versions.
#
# Your workspace\, .env and docker-compose.override.yml are never touched.

$ErrorActionPreference = "Stop"

$RepoSlug = "wmo4buva/cc-install"
$Ref = if ($env:CC_INSTALL_REF) { $env:CC_INSTALL_REF } else { "main" }
$ZipUrl = "https://codeload.github.com/$RepoSlug/zip/$Ref"

function Write-ErrorMsg { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Info     { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Warn     { param([string]$m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }
function Write-Success  { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }

if (-not (Test-Path "docker-compose.yml")) {
    Write-ErrorMsg "docker-compose.yml not found"
    Write-Host "Please run this script from the cc-install directory"
    exit 1
}

$InstallDir = (Get-Location).Path

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Blue
Write-Host "   Claude Code Updater" -ForegroundColor Blue
Write-Host "===========================================================" -ForegroundColor Blue
Write-Host ""

$currentVersion = if (Test-Path "VERSION") { (Get-Content "VERSION" -Raw).Trim() } else { "unknown" }
Write-Host "Installed version: " -NoNewline
Write-Host $currentVersion -ForegroundColor Yellow
Write-Host ""
Write-Info "This will update:"
Write-Host "  - The cc-install scripts and docs"
Write-Host "  - Claude Code (latest)"
Write-Host "  - VS Code Server / code-server (latest)"
Write-Host "  - System packages"
Write-Host ""
Write-Warn "Your workspace\, sign-in and settings will NOT be affected."
Write-Host ""
$response = Read-Host "Continue? (y/N)"

if ($response -notmatch '^[Yy]$') {
    Write-Info "Update cancelled"
    exit 0
}

# --- 1. Refresh the cc-install files ---------------------------------------
# PowerShell reads the whole script into memory before running it, so unlike the
# bash version this can safely overwrite itself mid-run.
Write-Info "Downloading the latest cc-install files..."

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cc-update-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zipPath = Join-Path $tmpDir "cc-install.zip"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

    $extracted = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
    if (-not $extracted) { throw "Downloaded archive was empty" }

    # workspace\, .env and docker-compose.override.yml aren't in the archive, so
    # copying over the top leaves them alone.
    Copy-Item -Path (Join-Path $extracted.FullName "*") -Destination $InstallDir -Recurse -Force

    $newVersion = if (Test-Path "VERSION") { (Get-Content "VERSION" -Raw).Trim() } else { "latest" }
    Write-Success "Files updated to $newVersion"
}
catch {
    Write-Warn "Could not update the files ($($_.Exception.Message)) - rebuilding only"
}
finally {
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 2. Rebuild the image --------------------------------------------------
Write-Info "Stopping container..."
docker compose stop 2>&1 | Out-Null

Write-Info "Rebuilding Docker image (this takes 10-15 minutes)..."
docker compose build --no-cache --progress plain
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to rebuild Docker image"
    exit 1
}

Write-Info "Starting updated container..."
docker compose up -d --force-recreate
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to start container"
    exit 1
}

Write-Info "Waiting for container to be ready..."
for ($i = 0; $i -lt 30; $i++) {
    docker compose exec -T claude-code test -x /home/claudeuser/.local/bin/claude 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
}

# --- 3. Refresh the shortcuts ---------------------------------------------
# New versions can add commands (ccauth, ccdiagnose, ccupdate). Without this,
# existing installs would keep only the shortcuts they started with.
if (Test-Path "scripts\installers\setup-shortcuts.ps1") {
    Write-Info "Refreshing launch shortcuts..."
    try {
        & ".\scripts\installers\setup-shortcuts.ps1" -InstallDir $InstallDir | Out-Null
        Write-Success "Shortcuts refreshed"
    }
    catch {
        Write-Warn "Could not refresh shortcuts (not fatal)"
    }
}

# --- 4. Report -------------------------------------------------------------
$claudeVersion = docker compose exec -T claude-code claude --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) { Write-Success "Claude Code: $claudeVersion" }
else { Write-Warn "Could not verify the Claude Code version" }

$codeServerVersion = docker compose exec -T claude-code code-server --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) { Write-Success "code-server: $codeServerVersion" }
else { Write-Warn "Could not verify the code-server version" }

# The version check caches for 24h; drop it so the new version is picked up now.
Remove-Item -Path (Join-Path $env:TEMP "cc-install-version-check.txt") -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   Update Complete!" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
$finalVersion = if (Test-Path "VERSION") { (Get-Content "VERSION" -Raw).Trim() } else { "unknown" }
Write-Host "Now at version: " -NoNewline
Write-Host $finalVersion -ForegroundColor Green
Write-Host ""
Write-Host "Start Claude Code:" -ForegroundColor Blue
Write-Host "  ccdocker" -ForegroundColor Yellow -NoNewline
Write-Host "   in your terminal"
Write-Host "  ccvscode" -ForegroundColor Yellow -NoNewline
Write-Host "   in your browser"
Write-Host ""
Write-Host "If a shortcut isn't found, open a new PowerShell window first." -ForegroundColor Yellow
Write-Host ""
