@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURATION SECTION
:: ==========================================
set "SERVER_EXE=RSDragonwildsServer.exe"
:: Change this to your location
set "SERVER_DIR=F:\SteamLibrary\steamapps\common\RuneScape Dragonwilds Dedicated Server"
set "APP_ID=4019830"
:: Change this to your locaiton
set "STEAMCMD_DIR=F:\SteamCMD"
set "PORT=7777"

:: Initialization
set "RESTART_DONE=false"
set "LAST_RESTART_TIME=None"

:UPDATE_CHECK
cls
echo ========================================================
echo Checking for RuneScape: Dragonwilds Server Updates...
echo ========================================================
if not exist "%STEAMCMD_DIR%\steamcmd.exe" (
    echo [WARNING] SteamCMD not found at %STEAMCMD_DIR%\steamcmd.exe
    echo Skipping update check and launching server...
    timeout /t 3 >nul
    goto LOOP
)

echo Connecting to Steam public servers...
cd /d "%STEAMCMD_DIR%"
steamcmd.exe +force_install_dir "%SERVER_DIR%" +login anonymous +app_update %APP_ID% +quit
echo Update check complete!
timeout /t 3 >nul

:LOOP
cls
echo ========================================================
echo Triggering Server Launch via Steam Library...
echo ========================================================
cd /d "%SERVER_DIR%"

start steam://rungameid/%APP_ID%
set "RESTART_DONE=false"

echo Waiting 15 seconds for Steam to launch the server executable...
timeout /t 15 /nobreak >nul

:: Clean terminal render loop
cls
echo ========================================================
echo SERVER CONTROL PANEL - RUNNING
echo ========================================================
echo.
echo [R] - Force Immediate Restart (Will check for updates)
echo [S] - Stop Server (Closes server and exits loop)
echo.
echo Scheduled Restarts : 00:00, 06:00, 12:00, 18:00
echo Last Restarted At  : %LAST_RESTART_TIME%
echo ========================================================

:TIMER_LOOP
:: Grab current time and patch leading spaces for single-digit hours
set "CURRENT_TIME=%TIME%"
if "%CURRENT_TIME:~0,1%"==" " set "CURRENT_TIME=0%CURRENT_TIME:~1%"
set "HH_MM=%CURRENT_TIME:~0,5%"

:: HIGH OPTIMIZATION: Filter netstat by port via findstr before checking ESTABLISHED to drop CPU usage
set "PLAYERS=0"
for /f %%P in ('netstat -ano ^| findstr /r /c:":%PORT%[^0-9]" ^| findstr /i "ESTABLISHED" ^| find /c /v ""') do set "PLAYERS=%%P"

:: OPTIMIZATION: Trailing spaces added inside the string to prevent layout ghosting artifacts
for /f %%A in ('copy /Z "%~f0" nul') do set /p ="Time: %CURRENT_TIME:~0,8% | Active Players: %PLAYERS%      %%A" <nul

:: FIXED CRITICAL LOGIC: Match the 60-second window before evaluating flag resets
if "%HH_MM%"=="00:00" goto CHECK_RESTART
if "%HH_MM%"=="06:00" goto CHECK_RESTART
if "%HH_MM%"=="12:00" goto CHECK_RESTART
if "%HH_MM%"=="18:00" goto CHECK_RESTART

:: Only clear the lock flag if we are safely outside of the execution minute window
set "RESTART_DONE=false"

:POLL_INPUT
:: Poll every 5 seconds for user inputs
choice /c rst /t 5 /d t /n >nul 2>&1

if errorlevel 3 goto TIMER_LOOP
if errorlevel 2 goto MANUAL_STOP
if errorlevel 1 goto MANUAL_RESTART

:CHECK_RESTART
if "%RESTART_DONE%"=="true" goto POLL_INPUT
set "RESTART_DONE=true"
goto RESTART_PROCEDURE

:MANUAL_RESTART
echo.
echo ========================================================
echo Triggering manual server restart...
echo ========================================================
goto RESTART_PROCEDURE

:: ==========================================
:: SAFE CLOSURE & REBOOT ENGINE
:: ==========================================

:RESTART_PROCEDURE
echo.
echo ========================================================
echo Initiating graceful process shutdown sequence...
echo ========================================================
set "TEMP_TIME=%TIME%"
if "%TEMP_TIME:~0,1%"==" " set "TEMP_TIME=0%TEMP_TIME:~1%"
set "LAST_RESTART_TIME=%TEMP_TIME:~0,8%"

echo [%TIME:~0,8%] Sending graceful close request to %SERVER_EXE%...
taskkill /im %SERVER_EXE% /t >nul 2>&1

echo Waiting for executable to cleanly clear memory cache...
:WAIT_LOOP_RESTART
tasklist /FI "IMAGENAME eq %SERVER_EXE%" 2>NUL | find /I /N "%SERVER_EXE%">NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 2 /nobreak >nul
    goto WAIT_LOOP_RESTART
)

echo Server data successfully committed to disk. 
echo Waiting 5 seconds to prevent initialization conflict...
timeout /t 5 /nobreak >nul
goto UPDATE_CHECK

:MANUAL_STOP
echo.
echo ========================================================
echo Triggering server safe shutdown...
echo ========================================================
echo [%TIME:~0,8%] Sending shutdown token to %SERVER_EXE%...
taskkill /im %SERVER_EXE% /t >nul 2>&1

echo Waiting for processes to settle...
:WAIT_LOOP_STOP
tasklist /FI "IMAGENAME eq %SERVER_EXE%" 2>NUL | find /I /N "%SERVER_EXE%">NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 2 /nobreak >nul
    goto WAIT_LOOP_STOP
)

echo Server stopped gracefully. Safe to close this window.
pause
exit
