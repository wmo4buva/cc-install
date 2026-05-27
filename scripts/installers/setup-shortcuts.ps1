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
    # Detect all PowerShell profile paths to handle both PowerShell 5.1 and 7+
    # PowerShell 5.1 uses: Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
    # PowerShell 7+   uses: Documents\PowerShell\Microsoft.PowerShell_profile.ps1

    $profilePaths = @()

    # Always add the current session's profile
    $profilePaths += $PROFILE.CurrentUserCurrentHost

    # Detect which PowerShell version is running and add the OTHER version's profile too
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # Running PowerShell 7+, also add 5.1 profile
        $ps51Profile = Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $ps51Profile
        Write-Info "Detected PowerShell 7+ - will configure both PowerShell 7 and 5.1 profiles"
    } else {
        # Running PowerShell 5.1, also add 7+ profile
        $ps7Profile = Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $ps7Profile
        Write-Info "Detected PowerShell 5.1 - will configure both PowerShell 5.1 and 7+ profiles"
    }

    # Remove duplicates
    $profilePaths = $profilePaths | Select-Object -Unique

    $configuredCount = 0
    foreach ($profilePath in $profilePaths) {
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
            Write-Success "Profile already configured: $profilePath"
            continue
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
        Write-Success "Configured profile: $profilePath"
        $configuredCount++
    }

    if ($configuredCount -gt 0) {
        Write-Host ""
        Write-Host "Shortcuts configured:" -ForegroundColor Blue
        Write-Host "  ccdocker   - Launch Claude Code CLI" -ForegroundColor Green
        Write-Host "  ccvscode   - Launch VS Code Server" -ForegroundColor Green
        Write-Host "  ccstop     - Stop the container" -ForegroundColor Green
        Write-Host "  cclogs     - View container logs" -ForegroundColor Green
        Write-Host "  ccrestart  - Restart the container" -ForegroundColor Green
    } else {
        Write-Success "All profiles already configured"
    }
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
