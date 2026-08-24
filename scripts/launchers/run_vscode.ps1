# VS Code Server (browser IDE) launcher for Windows.

$ErrorActionPreference = "Stop"

function Write-ErrorMsg { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Write-Info     { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Success  { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Write-Warn     { param([string]$m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }

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
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    exit 1
}

docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Docker daemon is not running"
    Write-Host "Please start Docker Desktop and try again"
    Write-Host "Run diagnostics: .\scripts\maintenance\diagnose.ps1" -ForegroundColor Yellow
    exit 1
}

$running = docker compose ps --status running 2>$null
if ($running -notmatch "claude-code") {
    Write-Info "Starting container..."
    docker compose up -d
    Start-Sleep -Seconds 2
}

# Which port did the user actually publish? Read it back from Compose rather
# than assuming 8080, so a docker-compose.override.yml still gets the right URL.
$hostPort = "8088"
$portLine = docker compose port claude-code 8080 2>$null
if ($portLine -match ':(\d+)\s*$') { $hostPort = $Matches[1] }
$url = "http://localhost:$hostPort"

# Is Claude Code already signed in? Either credentials in .env (API key /
# Bedrock), or an interactive login saved in the claude-config volume. If
# neither, the user will hit a sign-in prompt inside the IDE - so explain it up
# front, because that's the step people miss when they only use the browser IDE.
$signedIn = $false
if (Test-Path ".env") {
    if ((Get-Content ".env") -match '^\s*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|CLAUDE_CODE_USE_BEDROCK)=.+') {
        $signedIn = $true
    }
}
if (-not $signedIn) {
    docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>$null
    if ($LASTEXITCODE -eq 0) { $signedIn = $true }
}

# Drop a sign-in cheat sheet into the workspace. It's the first thing the user
# sees in the IDE's file explorer, which makes it the right place to explain
# something the browser IDE itself can't prompt for.
if (-not (Test-Path "workspace")) { New-Item -Path "workspace" -ItemType Directory | Out-Null }
$startHere = @'
# Start here

You're in **VS Code Server**, running inside the Claude Code container. Your
files live in this folder and are also on your computer at `workspace\`.

## How to use Claude Code in here

The browser IDE has no Claude Code button — you run it from the built-in
terminal, which is already inside the container:

1. Open the menu: **Terminal → New Terminal** (or press Ctrl+`)
2. Type `claude` and press Enter.

That's it. Claude Code runs in the terminal panel at the bottom.

## Signing in (first time only)

The first time you run `claude`, it asks how you want to authenticate.

**If you have a Claude subscription (Pro/Max/Team)** — pick the login option.
It prints a URL. **Copy the URL into a new browser tab** (Ctrl-click may not
work from the container terminal), sign in, copy the code it gives you, and
paste it back into the terminal. You only do this once — it's saved.

**If you were given an API key or UVA Bedrock credentials** — don't type them
into the terminal. Close this and run `ccauth` in a normal PowerShell window
instead. That stores them properly so both the CLI and this IDE pick them up,
and it survives updates.

**Already set up `ccauth`?** Then `claude` starts with no questions asked.

## Handy commands

| Command | What it does |
|---|---|
| `ccauth` | Set or change how you sign in (run in PowerShell, not in here) |
| `ccvscode` | Open this IDE |
| `ccdocker` | Use Claude Code in a normal terminal instead |
| `ccstop` | Shut the container down when you're done |

Full detail: `docs\CREDENTIALS.md` in the cc-install folder.
'@
Set-Content -Path "workspace\START-HERE.md" -Value $startHere -Encoding utf8

Write-Info "Starting VS Code Server..."

# Optional password, read from .env. Without one, code-server runs with no auth
# - which is fine only because docker-compose.yml publishes the port on
# 127.0.0.1. If you expose it to the network, set CC_VSCODE_PASSWORD.
$vscodePassword = ""
if (Test-Path ".env") {
    $pwLine = Get-Content ".env" | Where-Object { $_ -match '^\s*CC_VSCODE_PASSWORD=' } | Select-Object -Last 1
    if ($pwLine) { $vscodePassword = $pwLine.Split('=', 2)[1] }
}

docker compose exec -T claude-code pgrep -f code-server 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Info "VS Code Server is already running"
}
else {
    if ($vscodePassword) {
        docker compose exec -d -e "PASSWORD=$vscodePassword" claude-code code-server `
            --bind-addr 0.0.0.0:8080 `
            --auth password `
            /home/claudeuser/workspace
        Write-Info "Password protection is on (CC_VSCODE_PASSWORD from .env)"
    }
    else {
        docker compose exec -d claude-code code-server `
            --bind-addr 0.0.0.0:8080 `
            --auth none `
            /home/claudeuser/workspace
    }

    # Poll instead of a blind sleep, so slow machines don't open a dead tab.
    for ($i = 0; $i -lt 15; $i++) {
        docker compose exec -T claude-code pgrep -f code-server 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 1
    }
}

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "   VS Code Server is running" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Open in your browser: " -ForegroundColor Blue -NoNewline
Write-Host $url -ForegroundColor Yellow
Write-Host "  Your files:           workspace\" -ForegroundColor Blue
Write-Host ""

# The bit people get stuck on: there is no Claude Code button in the IDE.
Write-Host "To use Claude Code in the browser IDE:" -ForegroundColor White
Write-Host "  1. In VS Code, open Terminal -> New Terminal"
Write-Host "  2. Type " -NoNewline; Write-Host "claude" -ForegroundColor Yellow -NoNewline; Write-Host " and press Enter"
Write-Host ""

if ($signedIn) {
    Write-Host "[OK] Sign-in is already configured - " -ForegroundColor Green -NoNewline
    Write-Host "claude" -ForegroundColor Yellow -NoNewline
    Write-Host " will start straight away."
}
else {
    Write-Warn "You haven't set up a sign-in yet."
    Write-Host ""
    Write-Host "  Have an API key or UVA Bedrock credentials?" -ForegroundColor White
    Write-Host "  Run " -NoNewline; Write-Host "ccauth" -ForegroundColor Yellow -NoNewline
    Write-Host " first. That's the right place for keys - it saves them"
    Write-Host "  so both the CLI and this IDE use them."
    Write-Host ""
    Write-Host "  Have a Claude subscription (Pro/Max/Team)?" -ForegroundColor White
    Write-Host "  Just run " -NoNewline; Write-Host "claude" -ForegroundColor Yellow -NoNewline
    Write-Host " in the IDE terminal and follow the sign-in prompts."
    Write-Host "  Copy the URL it prints into a new browser tab."
    Write-Host ""
    Write-Host "  Details: docs\CREDENTIALS.md" -ForegroundColor Blue
}
Write-Host ""
Write-Host "Open START-HERE.md in the IDE for these instructions again." -ForegroundColor Blue
Write-Host ""

Write-Info "Opening browser..."
Start-Process $url

Write-Host ""
Write-Host "The server keeps running in the background - you can close this window."
Write-Host "Stop it later with: " -NoNewline; Write-Host "ccstop" -ForegroundColor Yellow
Write-Host ""
