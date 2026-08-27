@echo off
REM Claude Code CLI launcher for Windows
REM Usage: bin\claude.cmd  (or "ccdocker" once shortcuts are installed)
REM
REM cd's to the repo root (one level up from bin\), not to bin\ — every
REM "docker compose" call downstream resolves docker-compose.yml from the
REM working directory.

cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\launchers\run_claude.ps1" %*
