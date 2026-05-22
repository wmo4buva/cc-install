# VS Code Server Launcher Script for Windows

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

# Check Docker is installed
try {
    $null = docker --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not found"
    }
}
catch {
    Write-ErrorMsg "Docker is not installed"
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    exit 1
}

# Check Docker daemon is running
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not running"
    }
}
catch {
    Write-ErrorMsg "Docker daemon is not running"
    Write-Host "Please start Docker Desktop and try again"
    exit 1
}

# Check if container is running
$containerStatus = docker compose ps 2>&1
if ($containerStatus -notmatch "Up") {
    Write-Info "Starting container..."
    docker compose up -d
    Start-Sleep -Seconds 2
}

# Start code-server
Write-Info "Starting VS Code Server..."

# Check if code-server is already running
$codeServerRunning = docker compose exec -T claude-code pgrep -f code-server 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Info "VS Code Server is already running"
}
else {
    # Start code-server in background
    docker compose exec -d claude-code code-server `
        --bind-addr 0.0.0.0:8080 `
        --auth none `
        /home/claudeuser/workspace

    # Wait for code-server to start
    Start-Sleep -Seconds 3
}

# Display URL
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "║   VS Code Server is Running!                              ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Open in your browser:" -ForegroundColor Blue
Write-Host "  http://localhost:8080" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Your workspace: workspace\" -ForegroundColor Blue
Write-Host ""
Write-Host "Tip: Press Ctrl+C to stop following logs, or close this window." -ForegroundColor Yellow
Write-Host "     The server will continue running in the background." -ForegroundColor Yellow
Write-Host ""

# Open browser (Windows)
Write-Info "Opening browser..."
Start-Process "http://localhost:8080"

# Keep script running to show logs
Write-Info "Press Ctrl+C to exit (server will keep running)"
Write-Host ""
docker compose logs -f claude-code
