@echo off
REM VS Code Server launcher for Windows
REM Usage: vscode.cmd or just "vscode" from this directory

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launchers\run_vscode.ps1" %*
