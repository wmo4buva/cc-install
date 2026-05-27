# Check for updates to cc-install
# PowerShell version

param(
    [switch]$Silent
)

$ErrorActionPreference = "Continue"  # Don't stop on errors for silent checks

$RepoUrl = "https://raw.githubusercontent.com/wmo4buva/cc-install/main"
$LocalVersionFile = "VERSION"
$CacheFile = Join-Path $env:TEMP "cc-install-version-check.txt"
$CacheDuration = 86400  # 24 hours in seconds

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

# Get local version
function Get-LocalVersion {
    if (Test-Path $LocalVersionFile) {
        return (Get-Content $LocalVersionFile -Raw).Trim()
    }
    return "1.0.0"
}

# Get remote version (with caching)
function Get-RemoteVersion {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    # Check cache
    if (Test-Path $CacheFile) {
        $cacheTime = (Get-Item $CacheFile).LastWriteTimeUtc
        $cacheUnix = [DateTimeOffset]::new($cacheTime).ToUnixTimeSeconds()
        $age = $now - $cacheUnix

        if ($age -lt $CacheDuration) {
            return (Get-Content $CacheFile -Raw).Trim()
        }
    }

    # Fetch remote version
    try {
        $remoteVersion = (Invoke-WebRequest -Uri "$RepoUrl/VERSION" -UseBasicParsing -TimeoutSec 5).Content.Trim()

        if ($remoteVersion) {
            # Create cache directory if needed
            $cacheDir = Split-Path -Path $CacheFile -Parent
            if (-not (Test-Path $cacheDir)) {
                New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
            }

            $remoteVersion | Out-File -FilePath $CacheFile -Encoding UTF8 -NoNewline
            return $remoteVersion
        }
    }
    catch {
        # Return cached version if fetch fails
        if (Test-Path $CacheFile) {
            return (Get-Content $CacheFile -Raw).Trim()
        }
        return "unknown"
    }

    return "unknown"
}

# Compare versions (semver)
function Compare-Version {
    param(
        [string]$Version1,
        [string]$Version2
    )

    # Returns 1 if Version1 > Version2, 0 if equal, -1 if Version1 < Version2

    try {
        $v1 = [version]$Version1
        $v2 = [version]$Version2

        if ($v1 -gt $v2) { return 1 }
        if ($v1 -eq $v2) { return 0 }
        return -1
    }
    catch {
        # Fallback to string comparison
        if ($Version1 -eq $Version2) { return 0 }
        return [string]::Compare($Version1, $Version2)
    }
}

# Main check
function Test-ForUpdates {
    $localVersion = Get-LocalVersion
    $remoteVersion = Get-RemoteVersion

    if ($remoteVersion -eq "unknown") {
        # Silently skip if can't check
        return $false
    }

    $comparison = Compare-Version -Version1 $remoteVersion -Version2 $localVersion

    if ($comparison -gt 0) {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║                                                           ║" -ForegroundColor Yellow
        Write-Host "║   📦 Update Available!                                    ║" -ForegroundColor Yellow
        Write-Host "║                                                           ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Current version: " -NoNewline -ForegroundColor Blue
        Write-Host $localVersion
        Write-Host "Latest version:  " -NoNewline -ForegroundColor Green
        Write-Host $remoteVersion
        Write-Host ""
        Write-Host "To update, run:"
        Write-Host "  .\scripts\maintenance\update.ps1" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    else {
        return $false
    }
}

# Run check
try {
    if ($Silent) {
        Test-ForUpdates 2>$null | Out-Null
    }
    else {
        $updateAvailable = Test-ForUpdates
        if (-not $updateAvailable) {
            $localVersion = Get-LocalVersion
            Write-Success "You're running the latest version ($localVersion)"
        }
    }
}
catch {
    # Silently fail for silent checks
    if (-not $Silent) {
        Write-Warn "Could not check for updates: $_"
    }
}
