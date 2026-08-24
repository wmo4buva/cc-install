# Claude Code launcher for Windows.
#
# Usage: run_claude.ps1 [claude args...]
#        run_claude.ps1 bash | logs | stop | restart | auth

# Deliberately NOT named $Args — that collides with PowerShell's automatic
# $args variable.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CcArgs = @()
)

$ErrorActionPreference = "Stop"

function Write-ErrorMsg { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Info     { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Success  { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }

if (-not (Test-Path "docker-compose.yml")) {
    Write-ErrorMsg "docker-compose.yml not found"
    Write-Host "Please run this script from the cc-install directory"
    exit 1
}

# Check for updates (silent, non-blocking)
if (Test-Path "scripts\maintenance\check-update.ps1") {
    try { & ".\scripts\maintenance\check-update.ps1" -Silent } catch { }
}

docker --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Docker is not installed"
    Write-Host ""
    Write-Host "Please install Docker Desktop:"
    Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After installing, make sure Docker Desktop is running before trying again."
    exit 1
}

docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Docker daemon is not running"
    Write-Host ""
    Write-Host "Please start Docker Desktop:"
    Write-Host "  1. Find Docker Desktop in your Start menu"
    Write-Host "  2. Start it and wait ~30 seconds"
    Write-Host "  3. Look for the Docker icon in your system tray"
    Write-Host ""
    Write-Host "Run diagnostics: .\scripts\maintenance\diagnose.ps1" -ForegroundColor Yellow
    exit 1
}

$running = docker compose ps --status running 2>$null
if ($running -notmatch "claude-code") {
    Write-Info "Starting container..."
    docker compose up -d
    Start-Sleep -Seconds 2
}

# No args at all means "just launch Claude Code".
$command = if ($CcArgs.Count -gt 0) { $CcArgs[0] } else { "" }

switch ($command.ToLower()) {
    { $_ -in "bash", "shell" } {
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
        docker compose up -d --force-recreate
        Write-Success "Container restarted"
    }
    "auth" {
        & ".\scripts\installers\setup-credentials.ps1"
    }
    default {
        # First run with no credentials anywhere? Point at ccauth before Claude
        # Code drops the user into a sign-in prompt they weren't expecting.
        if (-not $command) {
            $hasEnvCreds = $false
            if (Test-Path ".env") {
                if ((Get-Content ".env") -match '^\s*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|CLAUDE_CODE_USE_BEDROCK)=.+') {
                    $hasEnvCreds = $true
                }
            }
            if (-not $hasEnvCreds) {
                docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host ""
                    Write-Host "First time here - you'll be asked to sign in." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  Claude subscription (Pro/Max/Team)? Just follow the prompts below."
                    Write-Host "  API key or UVA Bedrock credentials? Press Ctrl+C and run " -NoNewline
                    Write-Host "ccauth" -ForegroundColor Yellow -NoNewline
                    Write-Host " instead."
                    Write-Host ""
                    Write-Host "  Details: docs\CREDENTIALS.md" -ForegroundColor Blue
                    Write-Host ""
                }
            }
        }

        Write-Info "Launching Claude Code..."
        # Pass through only what the user actually typed. Passing $command
        # unconditionally used to send the literal string "claude" as a prompt.
        if ($CcArgs.Count -gt 0) {
            docker compose exec claude-code claude @CcArgs
        }
        else {
            docker compose exec claude-code claude
        }
    }
}
