# Diagnostic script for troubleshooting cc-install issues
# PowerShell version

$ErrorActionPreference = "Continue"

Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                           ║" -ForegroundColor Cyan
Write-Host "║   Claude Code Installation Diagnostics                   ║" -ForegroundColor Cyan
Write-Host "║                                                           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# System Information
Write-Host "═══ System Information ═══" -ForegroundColor Blue
Write-Host "OS: Windows $([System.Environment]::OSVersion.Version)"
Write-Host "Architecture: $env:PROCESSOR_ARCHITECTURE"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host ""

# Docker Check
Write-Host "═══ Docker Status ═══" -ForegroundColor Blue
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Docker installed" -ForegroundColor Green
        Write-Host "  Version: $dockerVersion"

        try {
            $null = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[SUCCESS] Docker daemon running" -ForegroundColor Green

                # Docker resources
                Write-Host ""
                Write-Host "Docker Resources:" -ForegroundColor Blue
                $dockerInfo = docker info 2>$null
                $dockerInfo | Select-String -Pattern "CPUs:|Total Memory:|Docker Root Dir:" | ForEach-Object {
                    Write-Host "  $($_.Line.Trim())"
                }
            }
            else {
                Write-Host "[ERROR] Docker daemon NOT running" -ForegroundColor Red
                Write-Host "[WARNING] Solution: Start Docker Desktop and wait for it to fully load" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[ERROR] Docker daemon NOT running" -ForegroundColor Red
            Write-Host "[WARNING] Solution: Start Docker Desktop and wait for it to fully load" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "[ERROR] Docker NOT installed" -ForegroundColor Red
    Write-Host "[WARNING] Solution: Install Docker Desktop from https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
}
Write-Host ""

# Docker Compose Check
Write-Host "═══ Docker Compose Status ═══" -ForegroundColor Blue
try {
    $composeVersion = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Docker Compose available" -ForegroundColor Green
        Write-Host "  Version: $composeVersion"
    }
    else {
        Write-Host "[ERROR] Docker Compose NOT available" -ForegroundColor Red
        Write-Host "[WARNING] Solution: Update Docker Desktop to get Docker Compose V2" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] Docker Compose NOT available" -ForegroundColor Red
    Write-Host "[WARNING] Solution: Update Docker Desktop to get Docker Compose V2" -ForegroundColor Yellow
}
Write-Host ""

# Container Status
Write-Host "═══ Container Status ═══" -ForegroundColor Blue
if (Test-Path "docker-compose.yml") {
    Write-Host "[SUCCESS] docker-compose.yml found" -ForegroundColor Green

    try {
        $containerStatus = docker compose ps 2>&1
        if ($containerStatus -match "cc-install") {
            Write-Host "[SUCCESS] Container exists" -ForegroundColor Green

            if ($containerStatus -match "Up") {
                Write-Host "[SUCCESS] Container is running" -ForegroundColor Green

                # Container details
                Write-Host ""
                Write-Host "Container Details:" -ForegroundColor Blue
                docker compose ps
            }
            else {
                Write-Host "[WARNING] Container exists but is not running" -ForegroundColor Yellow
                Write-Host "[WARNING] Solution: Run: .\scripts\launchers\run_claude.ps1" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "[WARNING] Container does not exist" -ForegroundColor Yellow
            Write-Host "[WARNING] Solution: Run: docker compose up -d" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[WARNING] Container does not exist" -ForegroundColor Yellow
        Write-Host "[WARNING] Solution: Run: docker compose up -d" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[ERROR] docker-compose.yml NOT found" -ForegroundColor Red
    Write-Host "[WARNING] Solution: Make sure you're in the cc-install directory" -ForegroundColor Yellow
}
Write-Host ""

# Port Check
Write-Host "═══ Port Availability ═══" -ForegroundColor Blue
try {
    $portCheck = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($portCheck) {
        Write-Host "[WARNING] Port 8080 is in use" -ForegroundColor Yellow
        Write-Host "Process using port 8080:" -ForegroundColor Blue
        $portCheck | Select-Object -First 1 | ForEach-Object {
            $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "  Process: $($process.ProcessName) (PID: $($process.Id))"
            }
        }
        Write-Host ""
        Write-Host "[WARNING] Solution: Stop the process or change port in docker-compose.yml" -ForegroundColor Yellow
    }
    else {
        Write-Host "[SUCCESS] Port 8080 is available" -ForegroundColor Green
    }
}
catch {
    Write-Host "[WARNING] Cannot check port status" -ForegroundColor Yellow
}
Write-Host ""

# Disk Space Check
Write-Host "═══ Disk Space ═══" -ForegroundColor Blue
try {
    $drive = (Get-Location).Drive
    $driveInfo = Get-PSDrive -Name $drive.Name
    $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
    $usedGB = [math]::Round($driveInfo.Used / 1GB, 2)
    $totalGB = [math]::Round(($driveInfo.Free + $driveInfo.Used) / 1GB, 2)
    $percentUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)

    Write-Host "Available disk space:" -ForegroundColor Blue
    Write-Host "  Total: ${totalGB}GB"
    Write-Host "  Used:  ${usedGB}GB"
    Write-Host "  Free:  ${freeGB}GB ($percentUsed% used)"

    if ($freeGB -lt 5) {
        Write-Host "[WARNING] Low disk space (less than 5GB free)" -ForegroundColor Yellow
        Write-Host "[WARNING] Solution: Free up disk space before installing" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARNING] Cannot check disk space" -ForegroundColor Yellow
}
Write-Host ""

# Workspace Check
Write-Host "═══ Workspace ═══" -ForegroundColor Blue
if (Test-Path "workspace") {
    Write-Host "[SUCCESS] Workspace directory exists" -ForegroundColor Green
    try {
        $wsSize = (Get-ChildItem workspace -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $wsSizeMB = [math]::Round($wsSize / 1MB, 2)
        Write-Host "  Size: ${wsSizeMB}MB"

        $wsFiles = (Get-ChildItem workspace -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Host "  Files: $wsFiles"
    }
    catch {
        Write-Host "  (Unable to calculate size)"
    }
}
else {
    Write-Host "[WARNING] Workspace directory not found" -ForegroundColor Yellow
    Write-Host "[WARNING] Solution: Will be created on first run" -ForegroundColor Yellow
}
Write-Host ""

# Docker Volumes Check
Write-Host "═══ Docker Volumes ═══" -ForegroundColor Blue
try {
    $volumes = docker volume ls 2>&1
    if ($volumes -match "claude-config") {
        Write-Host "[SUCCESS] claude-config volume exists" -ForegroundColor Green
        docker volume inspect cc-install_claude-config 2>$null | Select-String -Pattern "Name|Mountpoint" | ForEach-Object {
            Write-Host "  $($_.Line.Trim())"
        }
    }
    else {
        Write-Host "[WARNING] claude-config volume not found" -ForegroundColor Yellow
        Write-Host "[WARNING] Solution: Will be created on first run" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARNING] Cannot check Docker volumes" -ForegroundColor Yellow
}
Write-Host ""

# Image Check
Write-Host "═══ Docker Image ═══" -ForegroundColor Blue
try {
    $images = docker images 2>&1
    if ($images -match "cc-install") {
        Write-Host "[SUCCESS] cc-install image exists" -ForegroundColor Green
        docker images cc-install --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
    }
    else {
        Write-Host "[WARNING] cc-install image not found" -ForegroundColor Yellow
        Write-Host "[WARNING] Solution: Run: docker compose build" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[WARNING] Cannot check Docker images" -ForegroundColor Yellow
}
Write-Host ""

# Version Check
Write-Host "═══ Installation Version ═══" -ForegroundColor Blue
if (Test-Path "VERSION") {
    $version = (Get-Content "VERSION" -Raw).Trim()
    Write-Host "[SUCCESS] Installed version: $version" -ForegroundColor Green
}
else {
    Write-Host "[WARNING] VERSION file not found (older installation)" -ForegroundColor Yellow
    Write-Host "[WARNING] Solution: Run .\scripts\maintenance\update.ps1 to refresh this install" -ForegroundColor Yellow
}
Write-Host ""

# Sign-in / credentials
Write-Host "═══ Claude Code Sign-in ═══" -ForegroundColor Blue
$envLines = if (Test-Path ".env") { Get-Content ".env" } else { @() }
if ($envLines -match '^\s*CLAUDE_CODE_USE_BEDROCK=') {
    Write-Host "[SUCCESS] Configured for Amazon Bedrock (.env)" -ForegroundColor Green
    if (($envLines -match '^\s*AWS_ACCESS_KEY_ID=.+') -or ($envLines -match '^\s*AWS_PROFILE=.+')) {
        Write-Host "[SUCCESS] AWS credentials present" -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] CLAUDE_CODE_USE_BEDROCK is set but no AWS credentials found" -ForegroundColor Red
        Write-Host "[WARNING] Solution: Run: ccauth" -ForegroundColor Yellow
    }
}
elseif ($envLines -match '^\s*(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN)=.+') {
    Write-Host "[SUCCESS] Configured with an Anthropic API key (.env)" -ForegroundColor Green
}
else {
    docker compose exec -T claude-code test -s /home/claudeuser/.claude/.credentials.json 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Signed in interactively with a Claude account" -ForegroundColor Green
    }
    else {
        Write-Host "[WARNING] No sign-in configured yet" -ForegroundColor Yellow
        Write-Host "[WARNING] Solution: Run ccauth, or run ccdocker and sign in when prompted" -ForegroundColor Yellow
        Write-Host "          See docs\CREDENTIALS.md" -ForegroundColor Yellow
    }
}
Write-Host ""

# Is the IDE port exposed beyond this machine?
Write-Host "═══ Browser IDE Exposure ═══" -ForegroundColor Blue
$published = docker compose port claude-code 8080 2>$null
if (-not $published) {
    Write-Host "[WARNING] Container not running - cannot check" -ForegroundColor Yellow
}
elseif ($published -match '^127\.0\.0\.1:') {
    Write-Host "[SUCCESS] Published on $published (this machine only)" -ForegroundColor Green
}
else {
    Write-Host "[ERROR] Published on $published - reachable from your network" -ForegroundColor Red
    if ($envLines -match '^\s*CC_VSCODE_PASSWORD=.+') {
        Write-Host "[SUCCESS] A password is set, so it is not wide open" -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] No password set. Anyone who can reach this port gets a shell." -ForegroundColor Red
        Write-Host "[WARNING] Solution: Set CC_VSCODE_PASSWORD in .env, or publish on 127.0.0.1 only" -ForegroundColor Yellow
    }
}
Write-Host ""

# Common Issues Summary
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Common Solutions:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Docker not running:" -ForegroundColor Yellow
Write-Host "   Start Docker Desktop and wait ~30 seconds"
Write-Host ""
Write-Host "2. Port 8080 in use:" -ForegroundColor Yellow
Write-Host "   Copy docker-compose.override.yml.example to docker-compose.override.yml"
Write-Host "   and change the port to 127.0.0.1:8081:8080"
Write-Host ""
Write-Host "3. Container won't start:" -ForegroundColor Yellow
Write-Host "   Run: docker compose down && docker compose up -d"
Write-Host ""
Write-Host "4. Out of disk space:" -ForegroundColor Yellow
Write-Host "   Run: docker system prune -a"
Write-Host ""
Write-Host "5. Need to rebuild or get the latest fixes:" -ForegroundColor Yellow
Write-Host "   Run: .\scripts\maintenance\update.ps1"
Write-Host ""
Write-Host "6. Claude Code asks you to sign in every time:" -ForegroundColor Yellow
Write-Host "   Run: ccauth   (see docs\CREDENTIALS.md)"
Write-Host ""
Write-Host "7. Can't find Claude Code in the browser IDE:" -ForegroundColor Yellow
Write-Host "   There's no button - open Terminal -> New Terminal and type: claude"
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
