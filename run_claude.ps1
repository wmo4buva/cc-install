# Claude Code Launcher Script for Windows

param(
    [string]$Command = "claude",
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

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

# Determine command to run
switch ($Command.ToLower()) {
    {$_ -in "bash", "shell"} {
        Write-Info "Opening bash shell in container..."
        docker compose exec claude-code bash
    }
    "logs" {
        Write-Info "Showing container logs..."
        docker compose logs -f
    }
    "stop" {
        Write-Info "Stopping container..."
        docker compose stop
        Write-Success "Container stopped"
    }
    "restart" {
        Write-Info "Restarting container..."
        docker compose restart
        Write-Success "Container restarted"
    }
    default {
        Write-Info "Launching Claude Code..."
        if ($RemainingArgs) {
            docker compose exec claude-code claude $Command $RemainingArgs
        }
        else {
            docker compose exec claude-code claude $Command
        }
    }
}
