@echo off
REM Prefer double-clicking setup.cmd (hardware check + install in one go).
REM This file only runs the installer step.
REM Leave the window open until: ALL MODELS DOWNLOADED SUCCESSFULLY
cd /d "%~dp0"
echo.
echo  Ollama Ultimate Stack — installer
echo  Tip: for a full first-time run, use setup.cmd instead.
echo  Leave this window open. First run downloads Docker images + models (15-60 min).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
