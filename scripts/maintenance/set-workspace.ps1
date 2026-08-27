# Change which host folder is mounted as your workspace (Windows). "ccpath".
#
# Writes CC_WORKSPACE into .env; docker-compose.yml interpolates it as the source
# of the /home/claudeuser/workspace mount. The container side never changes, so
# nothing inside the image knows or cares where the files come from.
#
# Usage:
#   ccpath                      show the current path, then prompt for a new one
#   ccpath C:\path\to\folder    set it non-interactively
#   ccpath -Show                print the current path and exit
#   ccpath -Reset               go back to the bundled .\workspace

param(
    [Parameter(Position = 0)]
    [string]$Path,
    [switch]$Show,
    [switch]$Reset,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
Set-Location $installDir

. (Join-Path $scriptDir "..\lib\Workspace.ps1")

function Write-ErrorMsg { param([string]$Message) Write-Host "[ERROR] $Message"   -ForegroundColor Red }
function Write-Info     { param([string]$Message) Write-Host "[INFO] $Message"    -ForegroundColor Blue }
function Write-Success  { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warn     { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }

$envFile          = Join-Path $installDir ".env"
$defaultWorkspace = ".\workspace"

# ---------------------------------------------------------------------------

function Show-Current {
    $dir = Get-CcWorkspaceDir

    Write-Host ""
    Write-Host "Your workspace folder" -ForegroundColor White
    Write-Host ""
    Write-Host "  Host folder:      $dir" -ForegroundColor Blue
    Write-Host "  Inside container: /home/claudeuser/workspace  (never changes)" -ForegroundColor Blue

    if (Test-CcWorkspaceRelocated) {
        Write-Host "  Status:           relocated" -ForegroundColor Green
    } else {
        Write-Host "  Status:           default"
    }

    if (Test-Path $dir) {
        $files = @(Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue)
        $bytes = ($files | Measure-Object -Property Length -Sum).Sum
        $mb    = if ($bytes) { [math]::Round($bytes / 1MB, 1) } else { 0 }
        Write-Host "  Contents:         $($files.Count) files, $mb MB"
    } else {
        Write-Host "  Contents:         folder does not exist yet" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Docker Desktop on Windows shares drives rather than individual folders, but a
# UNC path is a different matter: bind-mounting one is unreliable and produces an
# empty mount rather than an error, which is a miserable thing to debug.
function Warn-IfUnshared {
    param([string]$Dir)

    if ($Dir.StartsWith("\\")) {
        Write-Warn "That's a network (UNC) path."
        Write-Host "         Docker Desktop cannot reliably bind-mount UNC paths - the folder"
        Write-Host "         usually shows up empty in the IDE with no error. Use a local"
        Write-Host "         folder, or map the share to a drive letter first."
        Write-Host ""
        return
    }

    $drive = if ($Dir -match '^([A-Za-z]):') { $Matches[1].ToUpper() } else { $null }
    if ($drive -and $drive -ne "C") {
        Write-Warn "That's on drive ${drive}:, which Docker Desktop may not be sharing."
        Write-Host "         If the folder shows up empty in the IDE, enable the drive under:"
        Write-Host "         Docker Desktop -> Settings -> Resources -> File sharing"
        Write-Host ""
    }
}

# Cloud-sync folders and a container writing to the same files is a recipe for
# corrupted saves and permission churn.
function Warn-IfCloudSynced {
    param([string]$Dir)

    $lower = $Dir.ToLower()
    foreach ($pattern in @("dropbox", "onedrive", "google drive", "googledrive", "icloud")) {
        if ($lower.Contains($pattern)) {
            Write-Warn "That looks like a cloud-synced folder."
            Write-Host "         The sync client and the container will both be writing to these"
            Write-Host "         files. That can corrupt saves mid-write and cause permission"
            Write-Host "         churn. A local folder is much safer; sync a backup instead."
            Write-Host ""
            return
        }
    }
}

# Absolute paths only, and forward slashes on the way into .env. Docker Desktop
# accepts C:/Users/... and it sidesteps any question of how backslashes survive
# Compose's own interpolation.
function Normalise-Path {
    param([string]$InputPath)

    $expanded = [Environment]::ExpandEnvironmentVariables($InputPath)
    if ($expanded.StartsWith("~")) {
        $expanded = Join-Path $env:USERPROFILE $expanded.TrimStart("~", "\", "/")
    }

    # Resolve to absolute without requiring the path to exist yet.
    if (-not [System.IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path (Get-Location).Path $expanded
    }
    $full = [System.IO.Path]::GetFullPath($expanded).TrimEnd('\', '/')

    return ($full -replace '\\', '/')
}

# Surgical rewrite: drop any existing CC_WORKSPACE line, append the new one.
# Mirrors how setup-credentials.ps1 edits .env so the two never fight, and leaves
# every other key (including credentials) untouched.
function Write-EnvVar {
    param([string]$Value)

    $lines = @()
    if (Test-Path $envFile) {
        $lines = @(Get-Content $envFile | Where-Object { $_ -notmatch '^\s*CC_WORKSPACE\s*=' })
    }

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $lines += "CC_WORKSPACE=$Value"
    }

    Set-Content -Path $envFile -Value $lines -Encoding UTF8
}

# Offer to bring existing files along. Copy, never move, and never delete the
# source - if something goes wrong the user still has their files.
function Invoke-Migration {
    param([string]$From, [string]$To)

    if (-not (Test-Path $From)) { return }

    $files = @(Get-ChildItem -Path $From -Recurse -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return }

    Write-Host ""
    Write-Info "Your current workspace has $($files.Count) file(s)."
    Write-Host "  From: $From" -ForegroundColor Blue
    Write-Host "  To:   $To"   -ForegroundColor Blue
    Write-Host ""
    Write-Host "Copy them to the new location? The originals are left exactly where they"
    Write-Host "are either way - nothing is deleted."
    $reply = Read-Host "Copy files? [y/N]"

    if ($reply -match '^[Yy]') {
        Write-Info "Copying..."
        try {
            Copy-Item -Path (Join-Path $From "*") -Destination $To -Recurse -Force -ErrorAction Stop
            Write-Success "Files copied. Originals still in $From"
        }
        catch {
            Write-ErrorMsg "Copy failed. Nothing was moved or deleted."
            Write-Host "        Your files are still in $From"
        }
    }
    else {
        Write-Info "Left files where they are."
        Write-Host "        The new workspace will start out empty."
    }
}

function Restart-Container {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Docker isn't running, so the container wasn't restarted."
        Write-Host "        Start Docker Desktop, then run: ccrestart"
        return
    }

    Write-Info "Recreating the container so the new mount takes effect..."

    # A plain restart is not enough - a bind mount is fixed at container
    # creation, so the container has to be recreated to pick up a new source.
    docker compose up -d --force-recreate 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Container recreated"
    } else {
        Write-Warn "Could not recreate the container automatically."
        Write-Host "        Run this yourself: ccrestart"
    }
}

# Prove the mount actually landed, rather than trusting that it did. A path
# Docker Desktop can't share produces an empty mount and no error at all.
function Confirm-Mount {
    param([string]$Expected)

    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { return }

    $fmt = '{{range .Mounts}}{{if eq .Destination "/home/claudeuser/workspace"}}{{.Source}}{{end}}{{end}}'
    $actual = (docker inspect cc-install --format $fmt 2>$null)

    if ([string]::IsNullOrWhiteSpace($actual)) {
        Write-Warn "Could not read the container's mounts to verify."
        return
    }

    $actual = $actual.Trim()

    if (Test-CcMountMatches $actual $Expected) {
        Write-Success "Verified: the container is mounting $Expected"
    } else {
        Write-Warn "The container is mounting a different path than expected."
        Write-Host "        Expected: $Expected"
        Write-Host "        Actual:   $actual"
        Write-Host "        Try: ccrestart"
    }
}

function Set-Workspace {
    param([string]$NewRaw)

    $oldPath = Get-CcWorkspaceDir

    if ($NewRaw -eq $defaultWorkspace) {
        $newPath = $defaultWorkspace
    } else {
        $newPath = Normalise-Path $NewRaw
    }

    if ($newPath -eq $oldPath) {
        Write-Info "Workspace is already set to that path. Nothing to do."
        return
    }

    if (-not (Test-Path $newPath)) {
        Write-Info "Creating $newPath"
        try {
            New-Item -Path $newPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-ErrorMsg "Could not create $newPath"
            Write-Host "        Check the path and that you have permission to write there."
            exit 1
        }
    }

    Warn-IfUnshared    $newPath
    Warn-IfCloudSynced $newPath

    Invoke-Migration $oldPath $newPath

    if ($newPath -eq $defaultWorkspace) {
        Write-EnvVar ""
        Write-Success "Workspace reset to the default .\workspace"
    } else {
        Write-EnvVar $newPath
        Write-Success "Workspace set to $newPath"
    }

    Restart-Container

    if ($newPath -ne $defaultWorkspace) {
        Confirm-Mount $newPath
    }

    $shown = if ($newPath -eq $defaultWorkspace) { Join-Path $installDir "workspace" } else { $newPath }

    Write-Host ""
    Write-Host "Done. Your files now live at:" -ForegroundColor White
    Write-Host "  $shown" -ForegroundColor Blue
    Write-Host ""
    Write-Host "In the browser IDE they still appear at /home/claudeuser/workspace, and"
    Write-Host "ccbackup now backs up the new location."
    Write-Host ""
    Write-Host "Remember: there is no Claude Code button in the browser IDE."
    Write-Host "Open a terminal in it and type: claude"
    Write-Host ""
}

# ---------------------------------------------------------------------------

if (-not (Test-Path "docker-compose.yml")) {
    Write-ErrorMsg "docker-compose.yml not found"
    Write-Host "Run this from your cc-install folder, or use the ccpath shortcut."
    exit 1
}

if ($Help) {
    Write-Host "Usage: ccpath [PATH] [-Show] [-Reset]"
    Write-Host ""
    Write-Host "  ccpath                     show the current folder, then prompt for a new one"
    Write-Host "  ccpath C:\path\to\folder   point your workspace at that folder"
    Write-Host "  ccpath -Show               print the current folder and exit"
    Write-Host "  ccpath -Reset              go back to the bundled .\workspace"
    Write-Host ""
    Write-Host "The folder inside the container is always /home/claudeuser/workspace."
    Write-Host "Only the host side changes, so nothing in the IDE moves around."
    exit 0
}

if ($Show) {
    Show-Current
    if (-not (Test-CcWorkspaceValid)) { exit 1 }
    exit 0
}

if ($Reset) {
    Set-Workspace $defaultWorkspace
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    Set-Workspace $Path
    exit 0
}

Show-Current
Test-CcWorkspaceValid | Out-Null
Write-Host "Enter the full path to the folder you want to use."
Write-Host "Leave blank to cancel, or type 'default' to go back to .\workspace."
Write-Host ""
$answer = Read-Host "New workspace path"

if ([string]::IsNullOrWhiteSpace($answer)) {
    Write-Info "Cancelled. Nothing changed."
    exit 0
}
elseif ($answer -eq "default") {
    Set-Workspace $defaultWorkspace
}
else {
    Set-Workspace $answer
}
