# Claude Code Faculty Installer - Installation Script for Windows
# Inspired by DAAF (https://github.com/DAAF-Contribution-Community/daaf)

param(
    [string]$InstallDir = "cc-install",
    [switch]$Verbose,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Configuration
$RepoUrl = "https://raw.githubusercontent.com/wmo4buva/cc-install/main"
$Interactive = [Environment]::UserInteractive

# Exit trap for interactive sessions
if ($Interactive) {
    $host.UI.RawUI.WindowTitle = "Claude Code Installer"
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-VerboseMsg {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
    }
}

# Dry-run mode
if ($DryRun) {
    Write-Warn "DRY RUN MODE - No actual changes will be made"
}

function Test-DockerInstalled {
    Write-Info "Checking Docker installation..."

    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-VerboseMsg "Docker found: $dockerVersion"
            return $true
        }
    }
    catch {
        return $false
    }

    return $false
}

function Test-DockerRunning {
    Write-Info "Checking Docker daemon..."

    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-VerboseMsg "Docker daemon is running"
            return $true
        }
    }
    catch {
        return $false
    }

    return $false
}

function Test-PreflightChecks {
    Write-Info "Running preflight checks..."

    # Check Docker installation
    if (-not (Test-DockerInstalled)) {
        Write-ErrorMsg "Docker is not installed or not in PATH"
        Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }

    # Check Docker daemon
    if (-not (Test-DockerRunning)) {
        Write-ErrorMsg "Docker daemon is not running"
        Write-Host "Please start Docker Desktop and try again" -ForegroundColor Yellow
        exit 1
    }

    # Check for existing installation
    if (Test-Path $InstallDir) {
        Write-Warn "Directory '$InstallDir' already exists"
        $response = Read-Host "Do you want to overwrite it? This will remove existing data. (y/N)"
        if ($response -notmatch '^[Yy]$') {
            Write-Info "Installation cancelled"
            exit 0
        }
        Write-Info "Removing existing directory..."
        if (-not $DryRun) {
            Remove-Item -Path $InstallDir -Recurse -Force
        }
    }

    Write-Success "Preflight checks passed"
}

function Get-Files {
    Write-Info "Step 1/5: Downloading required files..."

    # Root files
    $rootFiles = @(
        "Dockerfile",
        "docker-compose.yml",
        ".dockerignore",
        "README.md",
        "claude",
        "vscode",
        "claude.cmd",
        "vscode.cmd"
    )

    # Launcher scripts
    $launcherFiles = @(
        "scripts/launchers/run_claude.ps1",
        "scripts/launchers/run_vscode.ps1"
    )

    # Installer scripts
    $installerFiles = @(
        "scripts/installers/setup-shortcuts.ps1"
    )

    # Maintenance scripts
    $maintenanceFiles = @(
        "scripts/maintenance/update.ps1",
        "scripts/maintenance/backup.ps1",
        "scripts/maintenance/uninstall.ps1",
        "scripts/maintenance/restore.ps1"
    )

    $allFiles = $rootFiles + $launcherFiles + $installerFiles + $maintenanceFiles

    foreach ($file in $allFiles) {
        Write-VerboseMsg "Downloading $file..."

        if ($DryRun) {
            Write-Host "[DRY RUN] Would download $file" -ForegroundColor Gray
            # Create directory structure if needed
            $dir = Split-Path -Path $file -Parent
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
            }
            New-Item -Path $file -ItemType File -Force | Out-Null
            continue
        }

        try {
            # Create directory structure if needed
            $dir = Split-Path -Path $file -Parent
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
            }

            $url = "$RepoUrl/$file"
            Invoke-WebRequest -Uri $url -OutFile $file -ErrorAction Stop
        }
        catch {
            Write-ErrorMsg "Failed to download $file"
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }

    Write-Success "All files downloaded successfully"
}

function Build-Image {
    Write-Info "Step 2/5: Building Docker image (this may take a few minutes)..."

    if ($DryRun) {
        Write-Host "[DRY RUN] Would build Docker image" -ForegroundColor Gray
        return
    }

    try {
        docker compose build --progress plain
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed"
        }
    }
    catch {
        Write-ErrorMsg "Failed to build Docker image"
        Write-Host "Please check the error messages above and try again" -ForegroundColor Yellow
        exit 1
    }

    Write-Success "Docker image built successfully"
}

function Start-Container {
    Write-Info "Step 3/5: Starting container..."

    if ($DryRun) {
        Write-Host "[DRY RUN] Would start container" -ForegroundColor Gray
        return
    }

    try {
        docker compose up -d
        if ($LASTEXITCODE -ne 0) {
            throw "Docker compose up failed"
        }
    }
    catch {
        Write-ErrorMsg "Failed to start container"
        exit 1
    }

    # Wait for container to be ready
    Write-Info "Waiting for container to be ready..."
    $maxAttempts = 30
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        try {
            docker compose exec -T claude-code test -f /home/claudeuser/.local/bin/claude 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Container is ready"
                return
            }
        }
        catch {
            # Continue waiting
        }

        Start-Sleep -Seconds 2
        $attempt++
        Write-VerboseMsg "Attempt $attempt/$maxAttempts..."
    }

    Write-ErrorMsg "Container failed to start properly"
    Write-Host "Please check: docker compose logs" -ForegroundColor Yellow
    exit 1
}

function Initialize-Workspace {
    Write-Info "Step 4/5: Initializing workspace..."

    # Create workspace directory
    if (-not (Test-Path "workspace")) {
        New-Item -Path "workspace" -ItemType Directory | Out-Null
    }

    # Create welcome file
    $welcomeContent = @"
# Welcome to Claude Code!

This is your workspace directory. All files you create or edit in Claude Code will be stored here.

## Getting Started

1. Your Claude Code installation is ready to use
2. Run ``.\run_claude.ps1`` to start Claude Code CLI
3. Run ``.\run_vscode.ps1`` to open VS Code Server in your browser
4. Your files in this directory will persist across container restarts

## Need Help?

- See README.md for detailed usage instructions
- Visit https://claude.ai/code for Claude Code documentation
- Check the ATTRIBUTION.md file to learn about the project inspiration

Happy coding!
"@

    if (-not $DryRun) {
        $welcomeContent | Out-File -FilePath "workspace\WELCOME.md" -Encoding UTF8
    }

    Write-Success "Workspace initialized"
}

function Show-SuccessMessage {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "║   Claude Code Installation Complete!                      ║" -ForegroundColor Green
    Write-Host "║                                                           ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  1️⃣  Restart PowerShell, then launch from " -NoNewline
    Write-Host "anywhere" -ForegroundColor Yellow -NoNewline
    Write-Host ":"
    Write-Host "      ccdocker   " -ForegroundColor Green -NoNewline
    Write-Host "# Launch Claude Code CLI" -ForegroundColor Gray
    Write-Host "      ccvscode   " -ForegroundColor Green -NoNewline
    Write-Host "# Launch VS Code Server" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2️⃣  Or run from this directory:" -ForegroundColor Blue
    Write-Host "      claude.cmd " -ForegroundColor Yellow -NoNewline
    Write-Host "# Launch Claude Code CLI" -ForegroundColor Gray
    Write-Host "      vscode.cmd " -ForegroundColor Yellow -NoNewline
    Write-Host "# Launch VS Code Server" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3️⃣  Your files will be stored in:" -ForegroundColor Blue
    Write-Host "      $InstallDir\workspace\" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Blue
    Write-Host "  .\scripts\maintenance\update.ps1      - Update to latest versions" -ForegroundColor Yellow
    Write-Host "  .\scripts\maintenance\backup.ps1      - Backup your workspace" -ForegroundColor Yellow
    Write-Host "  .\scripts\maintenance\uninstall.ps1   - Remove everything" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "First-Time Setup:" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  When you first launch Claude Code, you'll need to:" -ForegroundColor White
    Write-Host "  - Enter your Anthropic API key" -ForegroundColor White
    Write-Host "  - Configure your preferences" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see README.md" -ForegroundColor Green
    Write-Host ""
}

# Main installation flow
function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                                                           ║" -ForegroundColor Blue
    Write-Host "║   Claude Code Faculty Installer                           ║" -ForegroundColor Blue
    Write-Host "║   Inspired by DAAF                                        ║" -ForegroundColor Blue
    Write-Host "║                                                           ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""

    Test-PreflightChecks

    # Create installation directory
    if (-not $DryRun) {
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        Set-Location $InstallDir
    }

    Get-Files
    Build-Image
    Start-Container
    Initialize-Workspace

    # Setup shortcuts for easy access
    Write-Info "Step 5/5: Setting up launch shortcuts..."

    # Ensure execution policy allows running scripts
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($currentPolicy -in @('Restricted', 'Undefined')) {
        Write-Info "Setting execution policy to RemoteSigned for current user..."
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
            Write-Success "Execution policy updated"
        }
        catch {
            Write-Warn "Could not update execution policy: $_"
            Write-Host "You may need to run PowerShell as Administrator to set execution policy" -ForegroundColor Yellow
        }
    }

    # Run setup-shortcuts with bypass to ensure it executes
    try {
        $shortcutScript = Join-Path $PWD.Path "scripts\installers\setup-shortcuts.ps1"
        & powershell.exe -ExecutionPolicy Bypass -File $shortcutScript -InstallDir $PWD.Path

        if ($LASTEXITCODE -ne 0) {
            throw "setup-shortcuts.ps1 exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-ErrorMsg "Failed to setup shortcuts: $_"
        Write-Warn "Installation is complete, but shortcuts were not configured"
        Write-Host "You can still launch using:" -ForegroundColor Yellow
        Write-Host "  .\claude.cmd   (from this directory)" -ForegroundColor Yellow
        Write-Host "  .\vscode.cmd   (from this directory)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To manually setup shortcuts later, run:" -ForegroundColor Yellow
        Write-Host "  .\scripts\installers\setup-shortcuts.ps1" -ForegroundColor Yellow
    }

    Show-SuccessMessage

    if ($Interactive) {
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
    }
}

# Run main function
try {
    Main
}
catch {
    Write-ErrorMsg "Installation failed: $_"
    if ($Interactive) {
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
    }
    exit 1
}
