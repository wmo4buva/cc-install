# Interactive credential setup for cc-install (Windows).
#
# Writes .\.env, which docker-compose.yml feeds into the container. Because the
# credentials live in the container's environment, they apply to BOTH ways of
# using Claude Code here:
#   ccdocker  - the CLI
#   ccvscode  - the browser IDE (its built-in terminal runs in the container)
#
# Run directly, or via the `ccauth` shortcut from anywhere.

param(
    # Pre-select a menu option instead of being prompted for it. Secrets are
    # always prompted for interactively — never pass a key on the command line,
    # it would end up in your shell history.
    [ValidateSet("", "1", "2", "3", "4", "5")]
    [string]$Choice = ""
)

$ErrorActionPreference = "Stop"

function Write-Info    { param([string]$m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Ok      { param([string]$m) Write-Host "[SUCCESS] $m" -ForegroundColor Green }
function Write-Warn    { param([string]$m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }
function Write-Err     { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# Always operate on the install directory, not wherever the user invoked us.
$InstallDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $InstallDir
$EnvFile = Join-Path $InstallDir ".env"

if (-not (Test-Path "docker-compose.yml")) {
    Write-Err "docker-compose.yml not found in $InstallDir"
    Write-Host "This does not look like a cc-install directory."
    exit 1
}

# --------------------------------------------------------------------------
# .env helpers
# --------------------------------------------------------------------------

# Strip any previously-set auth variables so the three options stay mutually
# exclusive. A leftover ANTHROPIC_API_KEY silently overrides a Claude account
# login, which is the single most confusing failure mode here.
$AuthVars = @(
    'CLAUDE_CODE_USE_BEDROCK', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_MODEL', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY',
    'AWS_SESSION_TOKEN', 'AWS_REGION', 'AWS_DEFAULT_REGION', 'AWS_PROFILE'
)

function Strip-AuthVars {
    if (-not (Test-Path $EnvFile)) {
        New-Item -Path $EnvFile -ItemType File -Force | Out-Null
        return
    }
    $pattern = '^\s*(' + ($AuthVars -join '|') + ')='
    $kept = @(Get-Content $EnvFile | Where-Object { $_ -notmatch $pattern })
    # UTF8 with no BOM and LF endings: this file is parsed by Docker on the
    # Linux side, and Compose does not strip a BOM (it would read the first
    # variable name as "<BOM>VAR" and ignore it).
    $text = if ($kept.Count) { ($kept -join "`n") + "`n" } else { "" }
    [System.IO.File]::WriteAllText($EnvFile, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-EnvVar {
    param([string]$Name, [string]$Value)
    # Append via .NET with an explicit no-BOM encoding. PowerShell 5.1's
    # `Add-Content -Encoding utf8` writes a BOM when it creates the file, and
    # Docker Compose does not strip BOMs — it would read the first variable
    # name as "<BOM>ANTHROPIC_API_KEY" and silently ignore it.
    # LF, not CRLF: this file is parsed by Docker on the Linux side.
    [System.IO.File]::AppendAllText(
        $EnvFile,
        "$Name=$Value`n",
        (New-Object System.Text.UTF8Encoding($false)))
}

function Read-Secret {
    param([string]$Prompt)
    do {
        $secure = Read-Host -Prompt $Prompt -AsSecureString
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        if (-not $plain) { Write-Warn "Cannot be empty - try again." }
    } while (-not $plain)
    return $plain
}

function Read-Plain {
    param([string]$Prompt, [string]$Default = "")
    $v = Read-Host -Prompt $Prompt
    if (-not $v) { return $Default }
    return $v
}

function Restart-CcContainer {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Docker isn't running, so the container wasn't restarted."
        Write-Host "        Start Docker Desktop, then run: ccrestart" -ForegroundColor Yellow
        return
    }
    Write-Info "Restarting the container so the new settings take effect..."
    docker compose up -d --force-recreate 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Could not restart automatically. Run: ccrestart"
        return
    }
    Write-Ok "Container restarted"
}

# --------------------------------------------------------------------------
# The three options
# --------------------------------------------------------------------------

function Use-ClaudeAccount {
    Strip-AuthVars
    Write-Ok "Set up to use your Claude account (interactive sign-in)"
    Write-Host ""
    Write-Host "One more step - you have to sign in once:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Run: " -NoNewline; Write-Host "ccdocker" -ForegroundColor Yellow
    Write-Host "  2. Claude Code will show a sign-in URL. Open it in your browser."
    Write-Host "  3. Log in, copy the code it gives you, paste it back in the terminal."
    Write-Host ""
    Write-Host "That's it - the login is saved and you won't be asked again."
    Write-Host "Using the browser IDE instead? See docs\CREDENTIALS.md." -ForegroundColor Blue
}

function Use-ApiKey {
    Write-Host ""
    Write-Host "Get a key at https://console.anthropic.com/settings/keys" -ForegroundColor Blue
    Write-Host "Note: usage is billed to whoever owns that key." -ForegroundColor Yellow
    Write-Host ""
    $key = Read-Secret "Anthropic API key (input hidden)"

    if ($key -notlike "sk-ant-*") {
        Write-Warn "That doesn't start with 'sk-ant-'. Saving it anyway, but double-check it."
    }

    Strip-AuthVars
    Set-EnvVar "ANTHROPIC_API_KEY" $key
    Write-Ok "API key saved to .env"
}

function Use-Bedrock {
    Write-Host ""
    Write-Host "Amazon Bedrock (UVA / Batten AWS account)" -ForegroundColor White
    Write-Host "Ask Batten IT for these if you don't have them."
    Write-Host ""

    $accessKey    = Read-Secret "AWS Access Key ID (input hidden)"
    $secretKey    = Read-Secret "AWS Secret Access Key (input hidden)"
    $region       = Read-Plain  "AWS Region [us-east-1]" "us-east-1"
    $sessionToken = Read-Plain  "AWS Session Token (only for temporary credentials, else press Enter)" ""
    $model        = Read-Plain  "Bedrock model ID (press Enter to use the default)" ""

    Strip-AuthVars
    Set-EnvVar "CLAUDE_CODE_USE_BEDROCK" "1"
    Set-EnvVar "AWS_ACCESS_KEY_ID" $accessKey
    Set-EnvVar "AWS_SECRET_ACCESS_KEY" $secretKey
    Set-EnvVar "AWS_REGION" $region
    Set-EnvVar "AWS_DEFAULT_REGION" $region
    if ($sessionToken) { Set-EnvVar "AWS_SESSION_TOKEN" $sessionToken }
    if ($model)        { Set-EnvVar "ANTHROPIC_MODEL" $model }

    Write-Ok "Bedrock credentials saved to .env"
}

function Clear-Credentials {
    Strip-AuthVars
    Write-Ok "Credentials removed from .env"
    Write-Host ""
    Write-Host "To also forget an interactive Claude account sign-in, run:"
    Write-Host "  ccdocker" -ForegroundColor Yellow -NoNewline
    Write-Host " then type " -NoNewline
    Write-Host "/logout" -ForegroundColor Yellow
}

function Show-Current {
    Write-Host ""
    Write-Host "Current setting" -ForegroundColor White
    if (-not (Test-Path $EnvFile)) {
        Write-Host "  No .env file yet - nothing configured." -ForegroundColor Yellow
        return
    }
    $content = Get-Content $EnvFile
    if ($content -match '^\s*CLAUDE_CODE_USE_BEDROCK=') {
        $regionLine = $content | Where-Object { $_ -match '^AWS_REGION=' } | Select-Object -First 1
        $region = if ($regionLine) { $regionLine.Split('=', 2)[1] } else { 'not set' }
        Write-Host "  Amazon Bedrock (region: $region)" -ForegroundColor Green
    }
    elseif ($content -match '^\s*ANTHROPIC_API_KEY=') {
        Write-Host "  Anthropic API key (value hidden)" -ForegroundColor Green
    }
    else {
        Write-Host "  Claude account (interactive sign-in), or not yet configured." -ForegroundColor Green
    }
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

# Seed .env from the example on first run so the file always exists and users
# have the reference comments to hand.
if ((-not (Test-Path $EnvFile)) -and (Test-Path ".env.example")) {
    Copy-Item ".env.example" $EnvFile
}

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Blue
Write-Host "   Claude Code - Sign-in Setup" -ForegroundColor Blue
Write-Host "===========================================================" -ForegroundColor Blue

Show-Current

Write-Host @"

How do you want to sign in to Claude Code?

  1) My Claude account          (recommended - Pro/Max/Team subscription)
  2) Anthropic API key          (personal, pay-as-you-go)
  3) Amazon Bedrock             (UVA / Batten AWS account)
  4) Clear saved credentials
  5) Quit without changing anything

Whichever you pick applies to BOTH ccdocker and ccvscode.
"@

if ($Choice) {
    $selection = $Choice
    Write-Info "Using preselected option $selection"
}
else {
    $selection = Read-Host "`nChoice [1-5]"
}
Write-Host ""

# Validate before the switch rather than relying on `default`. PowerShell's
# switch skips every clause — including default — when the value is $null, which
# Read-Host returns if there's no console. Without this, just pressing Enter fell
# straight through to the closing "all done" message having changed nothing.
$selection = "$selection".Trim()
if ($selection -notmatch '^[1-5]$') {
    if ($selection) { Write-Err "'$selection' isn't one of 1-5." }
    else            { Write-Err "No option chosen." }
    Write-Host "Run ccauth again and enter a number from 1 to 5." -ForegroundColor Yellow
    exit 1
}

switch ($selection) {
    "1" { Use-ClaudeAccount }
    "2" { Use-ApiKey;    Restart-CcContainer }
    "3" { Use-Bedrock;   Restart-CcContainer }
    "4" { Clear-Credentials; Restart-CcContainer }
    "5" { Write-Info "No changes made."; exit 0 }
}

Write-Host ""
Write-Host "Full details, including how to sign in from inside the browser IDE:" -ForegroundColor Blue
Write-Host "  $(Join-Path $InstallDir 'docs\CREDENTIALS.md')" -ForegroundColor Yellow
Write-Host ""

# Return a clean status. Without this the caller sees $LASTEXITCODE from
# whichever external command ran last (e.g. a failed `docker info`), which reads
# as a failure even though setup succeeded.
exit 0
