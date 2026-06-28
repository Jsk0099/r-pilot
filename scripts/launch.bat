@echo off
setlocal EnableDelayedExpansion

:: UserPromptSubmit hook (Windows): read the hook JSON from stdin and only launch
:: Review Pilot when the prompt invokes r-pilot. Prints nothing to the chat.
set "INPUT="
for /f "delims=" %%L in ('powershell -NoProfile -Command "[Console]::In.ReadToEnd()"') do set "INPUT=!INPUT!%%L"
echo !INPUT! | findstr /i "r-pilot" >nul
if errorlevel 1 exit /b 0

set PORT=3922
set SERVER=%~dp0..\server.js
set URL=http://localhost:%PORT%
set LOG=%TEMP%\reviewpilot-server.log
goto :main

:health_check
set HEALTH_OK=0
curl -s --max-time 1 "%URL%/health" >nul 2>&1
if %errorlevel% == 0 ( set HEALTH_OK=1 & goto :eof )
powershell -NoProfile -Command "try{$r=(iwr '%URL%/health' -UseBasicParsing -TimeoutSec 1).StatusCode;if($r -eq 200){exit 0}}catch{};exit 1" >nul 2>&1
if %errorlevel% == 0 set HEALTH_OK=1
goto :eof

:main
call :health_check
if "%HEALTH_OK%"=="1" goto open_browser

if not exist "%SERVER%" exit /b 0

start /b node "%SERVER%" > "%LOG%" 2>&1

for /l %%i in (1,1,5) do (
    timeout /t 1 /nobreak >nul
    call :health_check
    if "!HEALTH_OK!"=="1" goto open_browser
)
exit /b 0

:open_browser
start "" "%URL%"
exit /b 0
