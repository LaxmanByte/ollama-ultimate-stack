@echo off
REM Double-click this file after check-hardware.cmd
REM Leave the window open until it says ALL MODELS DOWNLOADED SUCCESSFULLY
cd /d "%~dp0"
echo.
echo  Ollama Ultimate Stack — installer
echo  Leave this window open. First run downloads Docker images + models (15-60 min).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
