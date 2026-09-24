@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-front.ps1" %*
exit /b %ERRORLEVEL%
