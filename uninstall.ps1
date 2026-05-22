# Uninstall Script for cc-install (Windows)
# Removes container, image, volumes, and optionally the installation directory

$ErrorActionPreference = "Stop"

# Logging functions
function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Check docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-ErrorMsg "docker-compose.yml not found"
    Write-Host "Please run this script from the cc-install directory"
    exit 1
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "║   Claude Code Uninstaller                                 ║" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

Write-Warn "This will remove:"
Write-Host "  • Docker container (cc-install)"
Write-Host "  • Docker image (cc-install:latest)"
Write-Host "  • Docker volumes (optional)"
Write-Host "  • Installation directory (optional)"
Write-Host ""

# Stop and remove container
Write-Info "Step 1/4: Stopping and removing container..."
try {
    docker compose down 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Container removed"
    }
    else {
        Write-Warn "Container may not exist or already removed"
    }
}
catch {
    Write-Warn "Container may not exist or already removed"
}

# Remove image
Write-Host ""
Write-Info "Step 2/4: Removing Docker image..."
try {
    docker rmi cc-install:latest 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Image removed"
    }
    else {
        Write-Warn "Image may not exist or already removed"
    }
}
catch {
    Write-Warn "Image may not exist or already removed"
}

# Remove volumes (with confirmation)
Write-Host ""
Write-Warn "Step 3/4: Remove Docker volumes?"
Write-Host "  This will DELETE your Claude Code settings and configuration."
Write-Host "  Your workspace\ directory will NOT be affected."
Write-Host ""
$response = Read-Host "Remove volumes? (y/N)"

if ($response -match '^[Yy]$') {
    try {
        docker volume rm cc-install_claude-config 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Volumes removed"
        }
        else {
            Write-Warn "Volumes may not exist or already removed"
        }
    }
    catch {
        Write-Warn "Volumes may not exist or already removed"
    }
}
else {
    Write-Info "Volumes preserved"
}

# Remove installation directory (with confirmation)
Write-Host ""
Write-Warn "Step 4/4: Remove installation directory?"
Write-Host "  This will DELETE the entire cc-install directory, including:"
Write-Host "    • workspace\ (YOUR FILES)"
Write-Host "    • All scripts and configuration"
Write-Host ""
$response = Read-Host "Remove installation directory? (y/N)"

if ($response -match '^[Yy]$') {
    $installDir = Get-Location
    Set-Location ..
    Write-Info "Removing $installDir..."
    try {
        Remove-Item -Path $installDir -Recurse -Force
        Write-Success "Installation directory removed"
        Write-Host ""
        Write-Host "Uninstallation complete. Claude Code has been fully removed." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-ErrorMsg "Failed to remove installation directory: $_"
        Write-Host "You may need to close any applications using files in this directory."
        exit 1
    }
}
else {
    Write-Info "Installation directory preserved"
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "║   Uninstallation Complete                                 ║" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Docker resources removed:" -ForegroundColor Blue
    Write-Host "  • Container: cc-install"
    Write-Host "  • Image: cc-install:latest"
    Write-Host ""
    Write-Host "Preserved:" -ForegroundColor Blue
    Write-Host "  • Installation directory (including workspace\)"
    Write-Host "  • Scripts (install.ps1, run_claude.ps1, etc.)"
    Write-Host ""
    Write-Host "To reinstall:" -ForegroundColor Yellow
    Write-Host "  Run: .\install.ps1"
    Write-Host ""
}
