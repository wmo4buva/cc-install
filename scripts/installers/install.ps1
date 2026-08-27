# Claude Code Installer - installation script for Windows
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)
#
# Usage (PowerShell, NOT Command Prompt):
#   irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex

param(
    [string]$InstallDir = "cc-install",
    [string]$Ref = "main",
    [switch]$ShowVerbose,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoSlug = "wmo4buva/cc-install"
$ZipUrl = "https://codeload.github.com/$RepoSlug/zip/$Ref"
$Interactive = [Environment]::UserInteractive

if ($Interactive) {
    $host.UI.RawUI.WindowTitle = "Claude Code Installer"
}

function Write-Info        { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Ok          { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Write-Warn        { param([string]$m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }
function Write-Err         { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-VerboseMsg  { param([string]$m) if ($ShowVerbose) { Write-Host "[VERBOSE] $m" -ForegroundColor Cyan } }

if ($DryRun) { Write-Warn "DRY RUN MODE - No actual changes will be made" }

function Test-PreflightChecks {
    Write-Info "Running preflight checks..."

    docker --version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker is not installed or not in PATH"
        Write-Host ""
        Write-Host "Step 1: Install Docker Desktop" -ForegroundColor Yellow
        Write-Host "  https://www.docker.com/products/docker-desktop/"
        Write-Host ""
        Write-Host "Step 2: Start Docker Desktop and wait ~30 seconds" -ForegroundColor Yellow
        Write-Host "Step 3: Run this installer again" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    Write-VerboseMsg "Docker found"

    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker is installed but not running"
        Write-Host ""
        Write-Host "Please start Docker Desktop:" -ForegroundColor Yellow
        Write-Host "  - Find Docker Desktop in your Start menu"
        Write-Host "  - Start it and wait ~30 seconds"
        Write-Host "  - Look for the Docker icon in your system tray"
        Write-Host ""
        exit 1
    }
    Write-VerboseMsg "Docker daemon is running"

    docker compose version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Docker Compose V2 is not available"
        Write-Host "Please update Docker Desktop to a recent version and try again." -ForegroundColor Yellow
        exit 1
    }

    if (Test-Path $InstallDir) {
        Write-Warn "Directory '$InstallDir' already exists"
        Write-Host ""
        Write-Host "If this is an existing cc-install, you probably want to UPDATE it"
        Write-Host "instead - that keeps your files and sign-in:"
        Write-Host "    cd $InstallDir; .\scripts\maintenance\update.ps1" -ForegroundColor Green
        Write-Host ""
        $response = Read-Host "Overwrite it instead? Your workspace\ and .env will be kept. (y/N)"
        if ($response -notmatch '^[Yy]$') {
            Write-Info "Installation cancelled"
            exit 0
        }
    }

    Write-Ok "Preflight checks passed"
}

# Download the whole repository as a zip.
#
# This used to fetch a hardcoded list of individual files, which drifted out of
# sync every time a file was added - that's how VERSION went missing (making
# every install permanently report "update available") and it would now also
# miss the Dockerfile's entrypoint. One archive can't drift.
function Get-Files {
    Write-Info "Step 1/5: Downloading cc-install ($Ref)..."

    if ($DryRun) {
        Write-Host "[DRY RUN] Would download $ZipUrl into $InstallDir" -ForegroundColor Gray
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        return
    }

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cc-install-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
    $zipPath = Join-Path $tmpDir "cc-install.zip"

    try {
        # TLS 1.2 for PowerShell 5.1 on older Windows builds, which otherwise
        # negotiates SSL3/TLS1.0 and gets refused by GitHub.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop

        Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

        # The zip wraps everything in a "cc-install-<ref>" directory. Copy its
        # contents up, leaving any existing workspace\ and .env untouched.
        $extracted = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
        if (-not $extracted) { throw "Downloaded archive was empty" }

        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $extracted.FullName "*") -Destination $InstallDir -Recurse -Force
    }
    catch {
        Write-Err "Failed to download cc-install from $ZipUrl"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Check your internet connection, then try again." -ForegroundColor Yellow
        exit 1
    }
    finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Ok "Files downloaded"
}

function Build-Image {
    Write-Info "Step 2/5: Building Docker image (this takes 10-15 minutes)..."
    Write-Host "        Good time to grab a coffee."

    if ($DryRun) { Write-Host "[DRY RUN] Would build Docker image" -ForegroundColor Gray; return }

    docker compose build --progress plain
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to build Docker image"
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        exit 1
    }

    Write-Ok "Docker image built successfully"
}

function Start-CcContainer {
    Write-Info "Step 3/5: Starting container..."

    if ($DryRun) { Write-Host "[DRY RUN] Would start container" -ForegroundColor Gray; return }

    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to start container"
        exit 1
    }

    Write-Info "Waiting for container to be ready..."
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        docker compose exec -T claude-code test -x /home/claudeuser/.local/bin/claude 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Container is ready"
            return
        }
        Start-Sleep -Seconds 2
        Write-VerboseMsg "Attempt $attempt/30..."
    }

    Write-Err "Container failed to start properly"
    Write-Host "Please check: docker compose logs" -ForegroundColor Yellow
    exit 1
}

function Initialize-Workspace {
    Write-Info "Step 4/5: Initializing workspace..."

    if (-not (Test-Path "workspace")) {
        New-Item -Path "workspace" -ItemType Directory | Out-Null
    }

    # Seed .env so credentials have somewhere to live and Compose always finds
    # the file. It contains only comments until the user runs ccauth.
    if ((-not (Test-Path ".env")) -and (Test-Path ".env.example")) {
        Copy-Item ".env.example" ".env"
    }

    $welcome = @'
# Welcome to Claude Code

Everything you put in this folder is saved on your computer (in `workspace\`)
and is visible inside Claude Code. It survives restarts and updates.

## Two ways to use it

| Command | What you get |
|---|---|
| `ccdocker` | Claude Code in your terminal |
| `ccvscode` | VS Code in your browser, with Claude Code in its terminal |

## Signing in

Run `ccauth` once and pick how you want to sign in — your Claude account, an
Anthropic API key, or UVA Amazon Bedrock. It applies to both commands above.

Using `ccvscode`? There's no Claude Code button in the browser IDE. Open
**Terminal → New Terminal** and type `claude`.

Full detail: `docs\CREDENTIALS.md`.

## Other commands

`ccstop` stop the container · `ccrestart` restart it · `cclogs` view logs

Docs: `README.md`, `docs\QUICK_REFERENCE.md`
'@

    if (-not $DryRun) {
        Set-Content -Path "workspace\WELCOME.md" -Value $welcome -Encoding utf8
    }

    Write-Ok "Workspace initialized"
}

function Show-SuccessMessage {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host "   Claude Code Installation Complete!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT: close this PowerShell window and open a NEW one." -ForegroundColor Yellow
    Write-Host "The shortcuts below won't exist in this one."
    Write-Host ""
    Write-Host "Then, in the new window:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Set up how you sign in (once):"
    Write-Host "     ccauth" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Start Claude Code:"
    Write-Host "     ccdocker" -ForegroundColor Yellow -NoNewline
    Write-Host "     in your terminal"
    Write-Host "     ccvscode" -ForegroundColor Yellow -NoNewline
    Write-Host "     in your browser (VS Code)"
    Write-Host ""
    Write-Host "  3. Your files live in:"
    Write-Host "     $((Get-Location).Path)\workspace\" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Using ccvscode? There's no Claude Code button in the browser IDE." -ForegroundColor Blue
    Write-Host "Open Terminal -> New Terminal and type " -NoNewline
    Write-Host "claude" -ForegroundColor Yellow -NoNewline
    Write-Host "."
    Write-Host ""
    Write-Host "Maintenance:" -ForegroundColor Blue
    Write-Host "  .\scripts\maintenance\update.ps1     update to the latest version" -ForegroundColor Yellow
    Write-Host "  .\scripts\maintenance\diagnose.ps1   check for problems" -ForegroundColor Yellow
    Write-Host "  .\scripts\maintenance\backup.ps1     back up your workspace" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Docs: README.md - sign-in help: docs\CREDENTIALS.md" -ForegroundColor Blue
    Write-Host ""
}

function Main {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Blue
    Write-Host "   Claude Code Installer" -ForegroundColor Blue
    Write-Host "   Inspired by DAAF" -ForegroundColor Blue
    Write-Host "===========================================================" -ForegroundColor Blue
    Write-Host ""

    Test-PreflightChecks
    Get-Files

    if (-not $DryRun) { Set-Location $InstallDir }

    Build-Image
    Start-CcContainer
    Initialize-Workspace

    Write-Info "Step 5/5: Setting up launch shortcuts..."

    # Allow local scripts to run for this user, otherwise the profile functions
    # we're about to write would be blocked from loading.
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($currentPolicy -in @('Restricted', 'Undefined')) {
        Write-Info "Setting execution policy to RemoteSigned for current user..."
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
            Write-Ok "Execution policy updated"
        }
        catch {
            Write-Warn "Could not update execution policy: $_"
            Write-Host "You may need to run PowerShell as Administrator to set execution policy" -ForegroundColor Yellow
        }
    }

    try {
        $shortcutScript = Join-Path (Get-Location).Path "scripts\installers\setup-shortcuts.ps1"
        & $shortcutScript -InstallDir (Get-Location).Path
    }
    catch {
        Write-Err "Failed to setup shortcuts: $_"
        Write-Warn "Installation is complete, but shortcuts were not configured"
        Write-Host "You can still launch using:" -ForegroundColor Yellow
        Write-Host "  .\bin\claude.cmd   (from this directory)" -ForegroundColor Yellow
        Write-Host "  .\bin\vscode.cmd   (from this directory)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To set up shortcuts later, run:" -ForegroundColor Yellow
        Write-Host "  .\scripts\installers\setup-shortcuts.ps1" -ForegroundColor Yellow
    }

    Show-SuccessMessage

    if ($Interactive) {
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
    }
}

try {
    Main
}
catch {
    Write-Err "Installation failed: $_"
    if ($Interactive) {
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
    }
    exit 1
}
