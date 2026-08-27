# Backup Script for cc-install (Windows)
# Creates a timestamped backup of the workspace directory

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

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Where the user's files actually live - .\workspace unless ccpath moved it.
$workspaceDir = Get-CcWorkspaceDir

if (-not (Test-Path $workspaceDir)) {
    Write-ErrorMsg "workspace directory not found: $workspaceDir"
    if (Test-CcWorkspaceRelocated) {
        Write-Host "CC_WORKSPACE in .env points there, but the folder is missing."
        Write-Host "Check it still exists, or repoint it with: ccpath"
    } else {
        Write-Host "Please run this script from the cc-install directory"
    }
    exit 1
}

# Create backups directory if it doesn't exist
if (-not (Test-Path "backups")) {
    New-Item -Path "backups" -ItemType Directory | Out-Null
}

# Generate timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = "backups\workspace_backup_$timestamp.zip"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "║   Workspace Backup Utility                                ║" -ForegroundColor Blue
Write-Host "║                                                           ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

Write-Info "Backing up: $(Get-CcWorkspaceLabel)"

# Check workspace size
$workspaceSize = (Get-ChildItem -Path $workspaceDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Info "Workspace size: $([math]::Round($workspaceSize, 2)) MB"

# Count files
$fileCount = (Get-ChildItem -Path $workspaceDir -Recurse -File).Count
Write-Info "Files to backup: $fileCount"

Write-Host ""
Write-Info "Creating backup: $backupFile"

try {
    # Create backup using Compress-Archive
    Compress-Archive -Path (Join-Path $workspaceDir "*") -DestinationPath $backupFile -CompressionLevel Optimal

    $backupSize = (Get-Item $backupFile).Length / 1MB

    Write-Host ""
    Write-Success "Backup created successfully!"
    Write-Host ""
    Write-Host "  File: $backupFile" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Green
    Write-Host ""
    Write-Host "To restore this backup:" -ForegroundColor Yellow
    Write-Host "  .\restore.ps1 $backupFile" -ForegroundColor Blue
    Write-Host ""
}
catch {
    Write-ErrorMsg "Backup failed: $_"
    exit 1
}

# List recent backups
Write-Host "Recent backups:" -ForegroundColor Blue
Get-ChildItem -Path "backups" | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | Format-Table Name, @{Name="Size (MB)";Expression={[math]::Round($_.Length / 1MB, 2)}}, LastWriteTime -AutoSize
Write-Host ""
