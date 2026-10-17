@echo off
chcp 65001 >nul
set "PATH=C:\Users\31598\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;%PATH%"
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-libretv.ps1"
exit