@echo off
REM Claude Code CLI launcher for Windows
REM Usage: claude.cmd or just "claude" from this directory

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launchers\run_claude.ps1" %*
