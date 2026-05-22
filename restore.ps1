# Restore Script for cc-install (Windows)
# Restores workspace from a backup file

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupFile
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

# Warning about existing workspace
if (Test-Path "workspace") {
    Write-Warn "This will REPLACE your current workspace directory!"
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
        Compress-Archive -Path "workspace\*" -DestinationPath "backups\workspace_before_restore_$timestamp.zip" -CompressionLevel Optimal 2>$null
    }
    catch {
        # Ignore errors if workspace is empty
    }
}

# Remove existing workspace
if (Test-Path "workspace") {
    Write-Info "Removing current workspace..."
    Remove-Item -Path "workspace" -Recurse -Force
}

# Create workspace directory
New-Item -Path "workspace" -ItemType Directory | Out-Null

# Extract backup
Write-Info "Restoring from backup..."
try {
    Expand-Archive -Path $BackupFile -DestinationPath "." -Force

    Write-Host ""
    Write-Success "Restore completed successfully!"
    Write-Host ""

    $fileCount = (Get-ChildItem -Path "workspace" -Recurse -File).Count
    Write-Host "  Files restored: $fileCount" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-ErrorMsg "Restore failed: $_"
    exit 1
}
