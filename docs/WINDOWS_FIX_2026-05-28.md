# Windows PowerShell Parsing Error - Fixed

**Date:** 2026-05-28  
**Version:** 1.2.1  
**Status:** ✅ RESOLVED

---

## Issue Summary

Users running `ccvscode` on Windows after installation encountered a PowerShell parsing error:

```
At C:\Users\bac7d\cc-install\scripts\launchers\run_vscode.ps1:103 char:60
+ Write-Info "Press Ctrl+C to exit (server will keep running)"
+                                                            ~
The string is missing the terminator: ".
```

## Root Cause

**PowerShell scripts had Unix (LF) line endings instead of Windows (CRLF) line endings.**

### Why This Happened
1. Files were created/edited on macOS/Linux with LF line endings
2. Git committed them with LF endings
3. When Windows users downloaded via installer, files retained LF endings
4. PowerShell on Windows expects CRLF endings for proper parsing
5. The LF endings caused PowerShell to misparse string quotes, thinking they were unterminated

### Why This Affects All .ps1 Files
- All 10 PowerShell scripts in the project had LF endings
- Any of them could have failed with similar errors
- `run_vscode.ps1` was discovered first because users tested `ccvscode`

## Solution

### 1. Created `.gitattributes`
```
# Ensure PowerShell scripts use Windows (CRLF) line endings
*.ps1 text eol=crlf

# Shell scripts use Unix (LF) line endings
*.sh text eol=lf

# Markdown and text files use native endings
*.md text
*.txt text

# Binary files
*.png binary
*.jpg binary
*.zip binary
*.tar.gz binary
```

### 2. What This Does
- **Forces CRLF for all `.ps1` files** on checkout, regardless of platform
- Maintains LF for `.sh` files (proper for bash)
- When Windows users download or clone, Git automatically converts endings
- Prevents future line ending issues

### 3. Testing
```powershell
# On Windows, after fix:
git clone https://github.com/wmo4buva/cc-install
cd cc-install
ccvscode  # Should work without parsing errors
```

## Verification

### Before Fix
```bash
$ file scripts/launchers/run_vscode.ps1
scripts/launchers/run_vscode.ps1: Unicode text, UTF-8 text
# No mention of CRLF
```

### After Fix
```bash
$ file scripts/launchers/run_vscode.ps1
scripts/launchers/run_vscode.ps1: Unicode text, UTF-8 text, with CRLF line terminators
```

### Git Line Ending Check
```bash
$ git ls-files --eol scripts/launchers/run_vscode.ps1
i/lf    w/crlf  attr/text eol=crlf    	scripts/launchers/run_vscode.ps1
```
- `i/lf` - Index has LF (old commit)
- `w/crlf` - Working tree has CRLF (after conversion)
- `attr/text eol=crlf` - .gitattributes enforces CRLF

## Impact

### Who Was Affected
- ✅ **All Windows users** running any `.ps1` script
- ❌ macOS/Linux users (not affected, bash uses `.sh` scripts)

### What Failed
- `ccvscode` command (most commonly tested)
- `ccdocker` command (if used)
- Any manual execution of `.ps1` scripts
- Installation script (`install.ps1`) might have had issues

### Symptoms
- PowerShell syntax errors
- "String is missing the terminator" errors
- Scripts failing to execute
- Users unable to launch VS Code Server

## User Action Required

### For New Users
**No action needed.** The fix is automatic when they download/clone.

### For Existing Users
Users who already installed need to update:

**Option 1: Update (Recommended)**
```powershell
cd cc-install
.\scripts\maintenance\update.ps1
```

**Option 2: Re-install**
```powershell
# Remove old installation
cd cc-install
.\scripts\maintenance\uninstall.ps1

# Re-run installer
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

**Option 3: Manual Fix (Advanced)**
```powershell
cd cc-install
git pull origin main
# Files will have correct endings after pull
```

## Prevention

### For Future Development

**When editing PowerShell files:**
1. Use an editor that respects `.gitattributes` (VS Code, JetBrains)
2. Set editor to use CRLF for `.ps1` files
3. Run `git ls-files --eol` before committing to verify

**When testing:**
1. Test all scripts on actual Windows machine
2. Don't assume macOS/Linux testing is sufficient for Windows
3. Check `file <script.ps1>` output includes "CRLF"

### Git Configuration
The `.gitattributes` file prevents this issue going forward:
- Git will automatically convert on checkout
- Works across all platforms
- No manual intervention needed

## Related Issues

This is similar to issues seen with:
- Bash scripts having CRLF on Linux (causes `\r: command not found`)
- Python scripts with wrong endings
- Any cross-platform scripting

The key principle:
> **Platform-specific scripts should use platform-appropriate line endings**
> - Windows scripts (`.ps1`, `.cmd`, `.bat`) → CRLF
> - Unix scripts (`.sh`) → LF
> - Cross-platform data (`.txt`, `.md`) → Git native

## Commits

- `f00d2e3` - Fix Windows PowerShell parsing error with line endings
- `5345e16` - Bump version to 1.2.1 and update CHANGELOG

## Resources

- [Git Documentation: gitattributes](https://git-scm.com/docs/gitattributes)
- [GitHub: Configuring Git to handle line endings](https://docs.github.com/en/get-started/getting-started-with-git/configuring-git-to-handle-line-endings)
- [PowerShell: About Special Characters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_special_characters)

---

**Status:** ✅ FIXED in v1.2.1  
**Deployed:** 2026-05-28  
**Testing:** Verified on Windows 11 PowerShell 7.5.5
