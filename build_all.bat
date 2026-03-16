@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File build_schedule_json.ps1
pause