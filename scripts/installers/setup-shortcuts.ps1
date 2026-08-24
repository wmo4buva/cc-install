# Create the cc* shortcut commands as PowerShell profile functions.
# Safe to re-run: it replaces the whole managed block so updates land.

param(
    [string]$InstallDir = $PWD.Path
)

$ErrorActionPreference = "Stop"

function Write-Info { param([string]$m) Write-Host $m -ForegroundColor Blue }
function Write-Ok   { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }

Write-Info "`nSetting up easy launch shortcuts...`n"

# Markers delimit the block we own, so re-running replaces it in place instead
# of appending a second copy or (as before) skipping it entirely — which meant
# existing installs never received newly added shortcuts like ccauth.
$BeginMarker = "# BEGIN cc-install shortcuts (managed - do not edit)"
$EndMarker   = "# END cc-install shortcuts"

function Get-ShortcutBlock {
    param([string]$Dir)

    return @"
$BeginMarker
function ccdocker   { Push-Location "$Dir"; try { & ".\claude.cmd" @args } finally { Pop-Location } }
function ccvscode   { Push-Location "$Dir"; try { & ".\vscode.cmd" @args } finally { Pop-Location } }
function ccauth     { Push-Location "$Dir"; try { & ".\scripts\installers\setup-credentials.ps1" @args } finally { Pop-Location } }
function ccstop     { Push-Location "$Dir"; try { & ".\scripts\launchers\run_claude.ps1" stop } finally { Pop-Location } }
function ccrestart  { Push-Location "$Dir"; try { & ".\scripts\launchers\run_claude.ps1" restart } finally { Pop-Location } }
function cclogs     { Push-Location "$Dir"; try { & ".\scripts\launchers\run_claude.ps1" logs } finally { Pop-Location } }
function ccdiagnose { Push-Location "$Dir"; try { & ".\scripts\maintenance\diagnose.ps1" } finally { Pop-Location } }
function ccbackup   { Push-Location "$Dir"; try { & ".\scripts\maintenance\backup.ps1" @args } finally { Pop-Location } }
function ccupdate   { Push-Location "$Dir"; try { & ".\scripts\maintenance\update.ps1" } finally { Pop-Location } }
$EndMarker
"@
}

function Set-PowerShellProfiles {
    # Configure BOTH PowerShell 5.1 and 7+ profiles, since users often have one
    # installed and launch the other.
    #   5.1 -> Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
    #   7+  -> Documents\PowerShell\Microsoft.PowerShell_profile.ps1
    $profilePaths = @()
    if ($PROFILE.CurrentUserCurrentHost) { $profilePaths += $PROFILE.CurrentUserCurrentHost }

    # GetFolderPath can return an EMPTY string — most often when Documents is
    # redirected (OneDrive on a managed machine) or in an unusual shell context.
    # Guard it: Join-Path on "" throws, and that used to abort the whole function,
    # leaving the user with no shortcuts at all and a "command not found" error.
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($documentsPath)) {
        Write-Warn "Could not locate your Documents folder; configuring only the active profile."
    }
    else {
        $otherProfile = if ($PSVersionTable.PSVersion.Major -ge 7) {
            Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        } else {
            Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1"
        }
        $profilePaths += $otherProfile
        $which = if ($PSVersionTable.PSVersion.Major -ge 7) { "7+ and 5.1" } else { "5.1 and 7+" }
        Write-Info "Configuring both PowerShell $which profiles"
    }

    $profilePaths = @($profilePaths | Where-Object { $_ } | Select-Object -Unique)
    if ($profilePaths.Count -eq 0) {
        throw "Could not determine any PowerShell profile path to write to"
    }

    $block = Get-ShortcutBlock -Dir $InstallDir
    $configured = 0

    foreach ($profilePath in $profilePaths) {
      # Per-profile try/catch: a failure on one profile (permissions, a synced
      # folder that's offline) must not stop the others from being configured.
      try {
        $profileDir = Split-Path -Path $profilePath -Parent
        if ($profileDir -and -not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }

        $existing = ""
        if (Test-Path $profilePath) {
            $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($null -eq $existing) { $existing = "" }
        }

        if ($existing -match [regex]::Escape($BeginMarker)) {
            # Replace our managed block, leaving the user's own profile intact.
            # Spliced by index rather than Regex.Replace, because the block
            # contains `$` (in `@args`-style code) and Regex.Replace would treat
            # those as capture-group references.
            $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker)
            $match = [regex]::Match($existing, $pattern)
            $updated = $existing.Substring(0, $match.Index) + $block +
                       $existing.Substring($match.Index + $match.Length)
            Set-Content -Path $profilePath -Value $updated -Encoding utf8
            Write-Ok "Updated shortcuts in: $profilePath"
        }
        else {
            # Strip a pre-1.3.0 unmarked block if one is there, so users don't
            # end up with two competing sets of ccdocker/ccvscode functions.
            if ($existing -match '# Claude Code shortcuts') {
                $existing = ($existing -split '# Claude Code shortcuts')[0]
                Write-Warn "Replaced an older unmarked shortcut block in $profilePath"
            }
            Set-Content -Path $profilePath -Value ($existing.TrimEnd() + "`r`n`r`n" + $block) -Encoding utf8
            Write-Ok "Configured profile: $profilePath"
        }
        $configured++
      }
      catch {
        Write-Warn "Could not configure $profilePath : $($_.Exception.Message)"
      }
    }

    if ($configured -eq 0) {
        throw "Could not write to any PowerShell profile"
    }

    Write-Host ""
    Write-Host "Shortcuts configured:" -ForegroundColor Blue
    Write-Host "  ccauth      Set up or change how you sign in" -ForegroundColor Green
    Write-Host "  ccdocker    Launch Claude Code CLI" -ForegroundColor Green
    Write-Host "  ccvscode    Launch VS Code Server (browser IDE)" -ForegroundColor Green
    Write-Host "  ccstop      Stop the container" -ForegroundColor Green
    Write-Host "  ccrestart   Restart the container" -ForegroundColor Green
    Write-Host "  cclogs      View container logs" -ForegroundColor Green
    Write-Host "  ccdiagnose  Check the install for problems" -ForegroundColor Green
    Write-Host "  ccbackup    Back up your workspace" -ForegroundColor Green
    Write-Host "  ccupdate    Update to the latest version" -ForegroundColor Green
}

function Show-Instructions {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host "  Shortcuts ready" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  1. Close this window and open a NEW PowerShell" -ForegroundColor Yellow
    Write-Host "     (or run: . `$PROFILE)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Set up how you sign in:"
    Write-Host "     ccauth" -ForegroundColor Green
    Write-Host ""
    Write-Host "  3. Start Claude Code:"
    Write-Host "     ccdocker" -ForegroundColor Green -NoNewline
    Write-Host "   in your terminal"
    Write-Host "     ccvscode" -ForegroundColor Green -NoNewline
    Write-Host "   in your browser"
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
}

try {
    Set-PowerShellProfiles
    Show-Instructions
}
catch {
    Write-Host "Error setting up shortcuts: $_" -ForegroundColor Red
    Write-Warn "You can still use the launchers from the installation directory:"
    Write-Host "  .\claude.cmd" -ForegroundColor Yellow
    Write-Host "  .\vscode.cmd" -ForegroundColor Yellow
    exit 1
}
