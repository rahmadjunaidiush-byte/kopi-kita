@echo off
cd /d "%~dp0"
set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if not exist "%PYTHON%" set "PYTHON=python"
"%PYTHON%" -m http.server 8000
if errorlevel 1 pause
