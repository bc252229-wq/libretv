@echo off
chcp 65001 >nul
title LibreTV
set "PATH=C:\Users\31598\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;%PATH%"
cd /d "%~dp0"
call "node_modules\.bin\next.CMD" start -p 8080
pause