@echo off
REM Windows start when Docker Desktop is already running.
REM If Smart App Control blocks this file: open PowerShell in this folder and run the two docker lines below.
cd /d "%~dp0"
title Ollama Ultimate Stack - start
echo.
echo  Docker Desktop must already be running.
echo  Leave this window open. First run downloads images and models.
echo.
docker compose up -d ollama open-webui
if errorlevel 1 (
  echo  Docker did not start. Open Docker Desktop, wait for Engine running, then run start.cmd again.
  echo  If Hub or GitHub registry denied: docker logout ghcr.io
  pause
  exit /b 1
)
echo.
echo  Downloading models. Done when you see: ALL MODELS DOWNLOADED SUCCESSFULLY
echo.
docker compose run --rm model-puller
echo.
echo  Open http://localhost:3000
echo  16GB laptops: pick qwen2.5-coder:3b if 7b is slow.
echo  AMD Radeon on Windows: Docker Ollama is CPU-only. For speed, pause Docker ollama
echo  and install https://ollama.com/download then keep Open WebUI running.
echo.
pause
