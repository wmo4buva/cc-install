# Update Script for cc-install (Windows)
# Rebuilds Docker image with latest versions

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
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "║   Claude Code Updater                                     ║" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

Write-Info "This will rebuild the Docker image with the latest versions of:"
Write-Host "  - Claude Code"
Write-Host "  - VS Code Server (code-server)"
Write-Host "  - System packages"
Write-Host ""
Write-Warn "Your workspace and settings will NOT be affected."
Write-Host ""
$response = Read-Host "Continue? (y/N)"

if ($response -notmatch '^[Yy]$') {
    Write-Info "Update cancelled"
    exit 0
}

# Stop container if running
Write-Info "Stopping container..."
try {
    docker compose stop 2>&1 | Out-Null
}
catch {
    # Container might not be running
}

# Rebuild image with no cache
Write-Info "Rebuilding Docker image (this may take a few minutes)..."
try {
    docker compose build --no-cache --progress plain
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
}
catch {
    Write-ErrorMsg "Failed to rebuild Docker image"
    exit 1
}

# Restart container
Write-Info "Starting updated container..."
try {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        throw "Start failed"
    }
}
catch {
    Write-ErrorMsg "Failed to start container"
    exit 1
}

# Wait for container to be ready
Write-Info "Waiting for container to be ready..."
Start-Sleep -Seconds 5

# Verify Claude Code
try {
    $claudeVersion = docker compose exec -T claude-code claude --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Claude Code updated: $claudeVersion"
    }
    else {
        Write-Warn "Could not verify Claude Code version"
    }
}
catch {
    Write-Warn "Could not verify Claude Code version"
}

# Verify code-server
try {
    $codeServerVersion = docker compose exec -T claude-code code-server --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "code-server updated: $codeServerVersion"
    }
    else {
        Write-Warn "Could not verify code-server version"
    }
}
catch {
    Write-Warn "Could not verify code-server version"
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "║   Update Complete!                                        ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "You can now use Claude Code with:" -ForegroundColor Blue
Write-Host "  .\run_claude.ps1 or .\run_vscode.ps1" -ForegroundColor Yellow
Write-Host ""
