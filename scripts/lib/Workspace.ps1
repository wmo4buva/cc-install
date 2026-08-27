# Shared workspace-path resolution (Windows).
#
# Dot-sourced by the launchers and maintenance scripts so every one of them agrees
# on where the user's files actually live on the host. Before this existed, six
# scripts hardcoded .\workspace; once the mount became relocatable that meant
# ccbackup would happily archive an empty .\workspace while the real files sat
# somewhere else entirely.
#
# Resolution order deliberately mirrors what Docker Compose does when it
# interpolates ${CC_WORKSPACE:-./workspace} in docker-compose.yml:
#   1. the process environment
#   2. .env in the install directory
#   3. the .\workspace default
# If these two ever disagree, the scripts operate on a different directory than
# the container mounts - so keep them in lockstep.

# Reads CC_WORKSPACE out of .env. Returns $null if unset or commented out.
# Takes the LAST assignment, matching how a shell would source the file.
function Get-CcWorkspaceFromEnvFile {
    param([string]$EnvFile = ".env")

    if (-not (Test-Path $EnvFile)) { return $null }

    $match = Select-String -Path $EnvFile -Pattern '^\s*CC_WORKSPACE\s*=' -ErrorAction SilentlyContinue |
             Select-Object -Last 1
    if (-not $match) { return $null }

    # Strip the key, then surrounding quotes. Compose treats quotes as optional
    # in .env, so a hand-edited CC_WORKSPACE="C:/some/path" has to work too.
    $raw = ($match.Line -replace '^\s*CC_WORKSPACE\s*=', '').Trim()
    $raw = $raw.Trim('"').Trim("'")

    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw
}

# The host workspace directory. Always returns something.
function Get-CcWorkspaceDir {
    if (-not [string]::IsNullOrWhiteSpace($env:CC_WORKSPACE)) { return $env:CC_WORKSPACE }

    $fromFile = Get-CcWorkspaceFromEnvFile
    if (-not [string]::IsNullOrWhiteSpace($fromFile)) { return $fromFile }

    return ".\workspace"
}

# True when the workspace has been pointed away from the bundled default.
function Test-CcWorkspaceRelocated {
    $dir = Get-CcWorkspaceDir
    return ($dir -ne ".\workspace" -and $dir -ne "./workspace" -and $dir -ne "workspace")
}

# A label for user-facing output: shows the path, and flags it as relocated so
# people aren't confused about why .\workspace looks empty.
function Get-CcWorkspaceLabel {
    $dir = Get-CcWorkspaceDir
    if (Test-CcWorkspaceRelocated) {
        return "$dir (relocated via ccpath)"
    }
    return $dir
}

# Compare a bind-mount source reported by `docker inspect` against a host path.
#
# Docker Desktop does not echo back the path you gave it - it reports bind sources
# through its VM, prefixed with /host_mnt, so C:\Users\you comes back as
# /host_mnt/c/Users/you. A naive string compare therefore reports a mismatch on
# every Docker Desktop install, which is worse than not checking at all: it tells
# people to recreate a container that is already correct, and trains them to ignore
# the warning when a real mismatch happens.
function Get-CcNormalisedMountPath {
    param([string]$Path)

    $p = ($Path -replace '\\', '/').ToLower().TrimEnd('/')
    if ($p.StartsWith('/host_mnt')) { $p = $p.Substring('/host_mnt'.Length) }

    # /c/users/... (Docker's form for a Windows drive) -> c:/users/...
    if ($p -match '^/([a-z])/(.*)$') { $p = "$($Matches[1]):/$($Matches[2])" }

    return $p
}

function Test-CcMountMatches {
    param([string]$Mounted, [string]$Expected)
    return (Get-CcNormalisedMountPath $Mounted) -eq (Get-CcNormalisedMountPath $Expected)
}

# Compose does not expand ~, and a relative path resolves against whatever
# directory the caller happened to be in. ccpath always writes absolute paths;
# this catches the case where someone edited .env by hand.
function Test-CcWorkspaceValid {
    $dir = Get-CcWorkspaceDir

    if ($dir.StartsWith("~")) {
        # Suggest the actual resolved path, not a literal "...", so the fix is
        # copy-pasteable. Mirrors cc_workspace_validate in workspace.sh.
        # Plain concatenation, not Join-Path: Join-Path resolves against PowerShell
        # drives and throws "Cannot find drive" if the profile's drive isn't
        # mounted. A validator must not throw while explaining a bad value.
        $rest = ($dir.TrimStart('~', '\', '/')) -replace '/', '\'
        $home = "$env:USERPROFILE".TrimEnd('\', '/')
        $suggested = if ($rest) { "$home\$rest" } else { $home }
        Write-Host "CC_WORKSPACE in .env starts with '~': $dir" -ForegroundColor Red
        Write-Host "Docker Compose does not expand ~, so this would mount a folder"
        Write-Host "literally named '~'. Fix it with: ccpath `"$suggested`""
        return $false
    }

    $isAbsolute = $dir -match '^[A-Za-z]:[\\/]' -or $dir.StartsWith("\\") -or $dir.StartsWith("/")
    $isDefault  = ($dir -eq ".\workspace" -or $dir -eq "./workspace" -or $dir -eq "workspace")

    if (-not $isAbsolute -and -not $isDefault) {
        Write-Host "CC_WORKSPACE in .env is a relative path: $dir" -ForegroundColor Red
        Write-Host "Use an absolute path so it resolves the same from any directory."
        Write-Host "Fix it with: ccpath C:\full\path\to\folder"
        return $false
    }

    return $true
}
