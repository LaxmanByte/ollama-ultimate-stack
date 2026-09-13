@echo off
REM =============================================================================
REM Ollama Ultimate Stack — one double-click for any Windows PC
REM Detects your machine (Intel / ARM, RAM, GPU). You do not pick an OS or model.
REM Leave this window open until: ALL MODELS DOWNLOADED SUCCESSFULLY
REM =============================================================================
cd /d "%~dp0"
title Ollama Ultimate Stack — Setup
echo.
echo  ============================================================================
echo   OLLAMA ULTIMATE STACK — SETUP
echo  ============================================================================
echo.
echo   You do not need to know Windows vs Mac, Intel vs ARM, or which AI model.
echo   We detect your PC and download what fits.
echo.
echo   Leave this window open (often 15-60 minutes on first run).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
set ERR=%ERRORLEVEL%
echo.
if not "%ERR%"=="0" (
  echo  Setup stopped with an error. Start Docker Desktop if needed, then run setup.cmd again.
  echo  Help: support@gridvoxsystems.com
)
echo.
pause
exit /b %ERR%
