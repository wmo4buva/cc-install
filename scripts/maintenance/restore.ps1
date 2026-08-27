# Restore Script for cc-install (Windows)
# Restores workspace from a backup file

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupFile
)

$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\lib\Workspace.ps1")

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

# Check if backup file provided
if (-not $BackupFile) {
    Write-ErrorMsg "No backup file specified"
    Write-Host "Usage: .\restore.ps1 <backup_file.zip>"
    Write-Host ""
    Write-Host "Available backups:"
    if (Test-Path "backups") {
        Get-ChildItem -Path "backups" | Format-Table Name, @{Name="Size (MB)";Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime -AutoSize
    }
    else {
        Write-Host "  (none found)"
    }
    exit 1
}

# Check backup file exists
if (-not (Test-Path $BackupFile)) {
    Write-ErrorMsg "Backup file not found: $BackupFile"
    exit 1
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "║   Workspace Restore Utility                               ║" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

Write-Info "Backup file: $BackupFile"
$backupSize = (Get-Item $BackupFile).Length / 1MB
Write-Host "  Size: $([math]::Round($backupSize, 2)) MB"
Write-Host ""

# Where the user's files actually live - .\workspace unless ccpath moved it.
if (-not (Test-CcWorkspaceValid)) { exit 1 }
$workspaceDir = Get-CcWorkspaceDir

# This script clears the workspace before extracting. Once the path is
# user-chosen that stops being a harmless operation on a folder we created, so
# refuse outright on anything that looks like a home directory or a drive root.
# Without this, pointing ccpath at %USERPROFILE% then restoring would wipe it.
if (Test-Path $workspaceDir) {
    $resolved = (Resolve-Path $workspaceDir).Path.TrimEnd('\', '/')

    if ($resolved -match '^[A-Za-z]:\\?$') {
        Write-ErrorMsg "Refusing to restore into $resolved"
        Write-Host "That's a drive root. Restoring would delete everything on it."
        Write-Host "Point your workspace somewhere dedicated first: ccpath"
        exit 1
    }

    if ($resolved -eq $env:USERPROFILE.TrimEnd('\', '/')) {
        Write-ErrorMsg "Refusing to restore into your home directory ($resolved)"
        Write-Host "Restoring clears the workspace first, which would delete everything"
        Write-Host "in your user folder. Point your workspace at a dedicated subfolder:"
        Write-Host "  ccpath `"$env:USERPROFILE\cc-workspace`""
        exit 1
    }
}

# Warning about existing workspace
if (Test-Path $workspaceDir) {
    Write-Warn "This will REPLACE the contents of your workspace!"
    Write-Host "  Folder: $(Get-CcWorkspaceLabel)" -ForegroundColor Blue
    Write-Host ""
    $response = Read-Host "Continue? (y/N)"

    if ($response -notmatch '^[Yy]$') {
        Write-Info "Restore cancelled"
        exit 0
    }

    # Backup current workspace first
    Write-Info "Creating safety backup of current workspace..."
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    if (-not (Test-Path "backups")) {
        New-Item -Path "backups" -ItemType Directory | Out-Null
    }
    try {
        Compress-Archive -Path (Join-Path $workspaceDir "*") -DestinationPath "backups\workspace_before_restore_$timestamp.zip" -CompressionLevel Optimal 2>$null
    }
    catch {
        # Ignore errors if workspace is empty
    }
}

# Clear the workspace, but keep the directory itself. It's a live bind-mount
# source: deleting and recreating it detaches the running container's mount, and
# on a relocated path it may also carry sharing permissions we can't restore.
if (Test-Path $workspaceDir) {
    Write-Info "Clearing current workspace contents..."
    Get-ChildItem -Path $workspaceDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path $workspaceDir -ItemType Directory -Force | Out-Null
}

# Extract backup.
#
# Into the workspace folder, NOT the install directory. backup.ps1 archives
# `workspace\*`, so the zip holds the workspace CONTENTS at its root - extracting
# to "." scattered them across the install folder and then reported 0 files
# restored, because it counted the freshly-emptied workspace. Fixed here.
Write-Info "Restoring from backup..."
try {
    Expand-Archive -Path $BackupFile -DestinationPath $workspaceDir -Force

    Write-Host ""
    Write-Success "Restore completed successfully!"
    Write-Host ""

    $fileCount = (Get-ChildItem -Path $workspaceDir -Recurse -File).Count
    Write-Host "  Files restored: $fileCount" -ForegroundColor Green
    Write-Host "  Location:       $workspaceDir" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-ErrorMsg "Restore failed: $_"
    exit 1
}
