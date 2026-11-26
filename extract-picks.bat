@echo off
setlocal DisableDelayedExpansion
set "PICKS_LIST=%~1"
set "PICKS_SOURCE=%~2"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0extract-picks.ps1"
set "result=%errorlevel%"
if not defined PICKS_SOURCE pause
exit /b %result%
