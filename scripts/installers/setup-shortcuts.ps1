# Setup shortcuts for easy Claude Code access after installation
# Windows PowerShell version

param(
    [string]$InstallDir = $PWD.Path
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

Write-Info "`nSetting up easy launch shortcuts...`n"

# Setup PowerShell profile functions
function Setup-PowerShellProfile {
    # Determine profile path
    $profilePath = $PROFILE.CurrentUserCurrentHost

    # Create profile directory if it doesn't exist
    $profileDir = Split-Path -Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    }

    # Create profile file if it doesn't exist
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
    }

    # Check if shortcuts already exist
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -match "# Claude Code shortcuts") {
        Write-Success "PowerShell profile already configured at $profilePath"
        return
    }

    # Add function definitions to profile
    $shortcutBlock = @"

# Claude Code shortcuts
function ccdocker {
    Push-Location "$InstallDir"
    & ".\claude.cmd"
    Pop-Location
}

function ccvscode {
    Push-Location "$InstallDir"
    & ".\vscode.cmd"
    Pop-Location
}

function ccstop {
    Push-Location "$InstallDir"
    & ".\scripts\launchers\run_claude.ps1" stop
    Pop-Location
}

function cclogs {
    Push-Location "$InstallDir"
    & ".\scripts\launchers\run_claude.ps1" logs
    Pop-Location
}

function ccrestart {
    Push-Location "$InstallDir"
    & ".\scripts\launchers\run_claude.ps1" restart
    Pop-Location
}
"@

    Add-Content -Path $profilePath -Value $shortcutBlock

    Write-Success "Added PowerShell functions to profile: $profilePath"
    Write-Host "  ccdocker   - Launch Claude Code CLI" -ForegroundColor Blue
    Write-Host "  ccvscode   - Launch VS Code Server" -ForegroundColor Blue
    Write-Host "  ccstop     - Stop the container" -ForegroundColor Blue
    Write-Host "  cclogs     - View container logs" -ForegroundColor Blue
    Write-Host "  ccrestart  - Restart the container" -ForegroundColor Blue
}

# Print instructions
function Print-Instructions {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Easy Launch Setup Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Quick Start:" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  1️⃣  " -NoNewline
    Write-Host "Restart PowerShell" -ForegroundColor Yellow
    Write-Host "      (or run: . `$PROFILE to reload)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2️⃣  Launch Claude Code from " -NoNewline
    Write-Host "anywhere" -ForegroundColor Yellow -NoNewline
    Write-Host ":"
    Write-Host "      ccdocker" -ForegroundColor Green
    Write-Host ""
    Write-Host "  3️⃣  Or launch VS Code Server:"
    Write-Host "      ccvscode" -ForegroundColor Green
    Write-Host ""
    Write-Host "Other Commands:" -ForegroundColor Blue
    Write-Host "  ccstop     - Stop the container" -ForegroundColor Green
    Write-Host "  cclogs     - View container logs" -ForegroundColor Green
    Write-Host "  ccrestart  - Restart the container" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
}

# Run setup
try {
    Setup-PowerShellProfile
    Print-Instructions
}
catch {
    Write-Host "Error setting up shortcuts: $_" -ForegroundColor Red
    Write-Warn "You can still use the launchers from the installation directory:"
    Write-Host "  .\scripts\launchers\run_claude.ps1" -ForegroundColor Yellow
    Write-Host "  .\scripts\launchers\run_vscode.ps1" -ForegroundColor Yellow
    exit 1
}
