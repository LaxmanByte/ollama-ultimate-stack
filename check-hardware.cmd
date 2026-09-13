@echo off
REM Double-click this file, or run: check-hardware.cmd
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-hardware.ps1"
echo.
pause
