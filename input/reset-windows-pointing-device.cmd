@echo off
setlocal
title Windows Mouse and Trackpad Reset

set "SCRIPT=%~dp0reset-windows-pointing-device.ps1"

if not exist "%SCRIPT%" (
    echo [ERROR] The PowerShell script was not found:
    echo %SCRIPT%
    echo.
    pause
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
    -NoLogo -NoProfile -File "%SCRIPT%" %*
set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" (
    echo.
    echo The reset tool ended with an error. See the message above.
)

exit /b %RESULT%
