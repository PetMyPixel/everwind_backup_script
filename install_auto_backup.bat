@echo off
setlocal enabledelayedexpansion
title Everwind Backup Manager
color 0A

:: =========================
:: ADMIN CHECK
:: =========================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator!
    pause
    exit /b
)

:: =========================
:: VARIABLES
:: =========================
set SCRIPT_PATH=C:\Scripts
set SCRIPT_FILE=%SCRIPT_PATH%\everwind_backup.ps1
set CONFIG_FILE=%SCRIPT_PATH%\everwind_config.ini
set LOG_FILE=%SCRIPT_PATH%\everwind_error.log
set TASK_NAME=Everwind Backup

goto start

:: =========================
:: LOG FUNCTION
:: =========================
:log
echo [%date% %time%] %* >> "%LOG_FILE%"
exit /b

:: =========================
:: SAVE CONFIG
:: =========================
:saveconfig
(
echo interval=%INTERVAL%
echo max_backups=%MAX_BACKUPS%
) > "%CONFIG_FILE%"
exit /b

:: =========================
:: REFRESH DATA
:: =========================
:refreshdata

set BACKUP_COUNT=0
set LAST_BACKUP=None

if exist "%BACKUP_PATH%" (
    for /f %%f in ('dir /b /o-d "%BACKUP_PATH%\*.zip" 2^>nul') do (
        set /a BACKUP_COUNT+=1
        if !BACKUP_COUNT! EQU 1 set LAST_BACKUP=%%f
    )
)

if exist "%SCRIPT_FILE%" (
    set STATUS=INSTALLED
) else (
    set STATUS=NOT INSTALLED
)

for /f "tokens=1,2 delims=:" %%a in ("%time%") do (
    set HH=%%a
    set MM=%%b
)

set HH=%HH: =%
set /a TOTAL_MIN=HH*60+MM
set /a NEXT_TOTAL=((TOTAL_MIN / %INTERVAL%) + 1) * %INTERVAL%

set /a NEXT_HH=NEXT_TOTAL/60
set /a NEXT_MM=NEXT_TOTAL%%60

if %NEXT_HH% GEQ 24 set /a NEXT_HH-=24

if %NEXT_HH% LSS 10 set NEXT_HH=0%NEXT_HH%
if %NEXT_MM% LSS 10 set NEXT_MM=0%NEXT_MM%

set NEXT_RUN=%NEXT_HH%:%NEXT_MM%

exit /b

:: =========================
:: START
:: =========================
:start

for /f "tokens=2 delims=\" %%a in ('whoami') do set USERNAME=%%a
set BASE_PATH=C:\Users\%USERNAME%\AppData\Local\Everwind\Saved
set BACKUP_PATH=%BASE_PATH%\Backups

:: LOAD CONFIG
if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in (%CONFIG_FILE%) do (
        if "%%a"=="interval" set INTERVAL=%%b
        if "%%a"=="max_backups" set MAX_BACKUPS=%%b
    )
)

if not defined INTERVAL set INTERVAL=60
if not defined MAX_BACKUPS set MAX_BACKUPS=3

:: =========================
:: MENU (UPDATED)
:: =========================
:menu
cls

call :refreshdata

echo =============================
echo   EVERWIND BACKUP MANAGER
echo =============================
echo.
echo Status:
echo   System: %STATUS%
echo   Interval: %INTERVAL% min
echo   Max Backups: %MAX_BACKUPS%
echo   Next Backup: %NEXT_RUN%
echo   Backups: %BACKUP_COUNT%
echo   Last Backup: %LAST_BACKUP%
echo.

echo === ACTIONS ===
echo 1. Backup Now
echo 2. Restore Backup
echo 3. Open Backup Folder
echo.

echo === SETTINGS ===
echo 4. Change Settings
echo 5. Install Backup System
echo 6. Uninstall
echo.

echo === TOOLS ===
echo 7. Verify Backups
echo 8. View Error Log
echo.

echo 9. Exit
echo.
echo (Press Enter to refresh)
echo.
set /p choice=Choose: 

if "%choice%"=="" goto menu

if "%choice%"=="1" goto backupnow
if "%choice%"=="2" goto restore
if "%choice%"=="3" goto openfolder
if "%choice%"=="4" goto settings
if "%choice%"=="5" goto install
if "%choice%"=="6" goto uninstall
if "%choice%"=="7" goto verify
if "%choice%"=="8" goto viewlog
if "%choice%"=="9" exit

goto menu

:: =========================
:: SETTINGS
:: =========================
:settings
cls
echo 1. Change Interval
echo 2. Change Backup Limit
echo 3. Back
set /p s=

if "%s%"=="1" goto changeInterval
if "%s%"=="2" goto changeLimit
goto menu

:: =========================
:: CHANGE INTERVAL
:: =========================
:changeInterval
cls
echo 1. 15 min
echo 2. 30 min
echo 3. 45 min
echo 4. 60 min
set /p i=

if "%i%"=="1" set INTERVAL=15
if "%i%"=="2" set INTERVAL=30
if "%i%"=="3" set INTERVAL=45
if "%i%"=="4" set INTERVAL=60

if not defined INTERVAL goto menu

call :saveconfig

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

schtasks /create ^
/tn "%TASK_NAME%" ^
/sc minute ^
/mo %INTERVAL% ^
/st 00:00 ^
/tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %SCRIPT_FILE%" ^
/ru SYSTEM ^
/rl highest ^
/f

if %errorlevel% neq 0 call :log ERROR updating interval

echo Updated interval!
pause
goto menu

:: =========================
:: CHANGE LIMIT
:: =========================
:changeLimit
cls
echo 1. 3 backups
echo 2. 5 backups
echo 3. 10 backups
set /p l=

if "%l%"=="1" set MAX_BACKUPS=3
if "%l%"=="2" set MAX_BACKUPS=5
if "%l%"=="3" set MAX_BACKUPS=10

if not defined MAX_BACKUPS goto menu

call :saveconfig

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$c = Get-Content '%SCRIPT_FILE%'; ^
$c = $c -replace 'if \(\$files\.Count -ge \d+\)', 'if ($files.Count -ge %MAX_BACKUPS%)'; ^
Set-Content '%SCRIPT_FILE%' $c"

if %errorlevel% neq 0 call :log ERROR updating backup limit

echo Updated backup limit!
pause
goto menu

:: =========================
:: INSTALL
:: =========================
:install
cls
mkdir %SCRIPT_PATH% >nul 2>&1

call :saveconfig

echo $ErrorActionPreference = "SilentlyContinue" > %SCRIPT_FILE%
echo if (-not (Get-Process Everwind -ErrorAction SilentlyContinue)) { exit } >> %SCRIPT_FILE%
echo $user = (Get-CimInstance Win32_ComputerSystem).UserName >> %SCRIPT_FILE%
echo $userName = $user.Split('\')[-1] >> %SCRIPT_FILE%
echo $basePath = "C:\Users\$userName\AppData\Local\Everwind\Saved" >> %SCRIPT_FILE%
echo $source = "$basePath\SaveGames" >> %SCRIPT_FILE%
echo $backupRoot = "$basePath\Backups" >> %SCRIPT_FILE%
echo $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm" >> %SCRIPT_FILE%
echo $zipPath = "$backupRoot\Everwind_$timestamp.zip" >> %SCRIPT_FILE%
echo if (!(Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot ^| Out-Null } >> %SCRIPT_FILE%

echo $files = Get-ChildItem $backupRoot -Filter *.zip ^| Sort-Object CreationTime >> %SCRIPT_FILE%
echo if ($files.Count -ge %MAX_BACKUPS%) { $files[0] ^| Remove-Item -Force } >> %SCRIPT_FILE%

echo Compress-Archive -Path "$source\*" -DestinationPath $zipPath -Force >> %SCRIPT_FILE%

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

schtasks /create ^
/tn "%TASK_NAME%" ^
/sc minute ^
/mo %INTERVAL% ^
/st 00:00 ^
/tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %SCRIPT_FILE%" ^
/ru SYSTEM ^
/rl highest ^
/f

if %errorlevel% neq 0 call :log ERROR installing scheduled task

echo Installed!
pause
goto menu

:: =========================
:: OTHER
:: =========================
:backupnow
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_FILE%" || call :log ERROR manual backup failed
echo Done!
pause
goto menu

:verify
for %%f in ("%BACKUP_PATH%\*.zip") do (
    powershell -command "try { Expand-Archive '%%f' $env:TEMP\t -ErrorAction Stop; Remove-Item $env:TEMP\t -Recurse -Force; Write-Host 'OK: %%~nxf' } catch { Write-Host 'CORRUPTED: %%~nxf' }"
)
pause
goto menu

:viewlog
if exist "%LOG_FILE%" type "%LOG_FILE%"
pause
goto menu

:uninstall
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
del "%SCRIPT_FILE%" /f /q
del "%CONFIG_FILE%" /f /q
echo Removed!
pause
goto menu

:restore
set SAVE_PATH=%BASE_PATH%\SaveGames
set count=0
for /f "delims=" %%f in ('dir /b /o-d "%BACKUP_PATH%\*.zip"') do (
    set /a count+=1
    echo !count!. %%f
    set "file!count!=%BACKUP_PATH%\%%f"
)
set /p pick=Select:
if not defined file%pick% goto menu
rmdir "%SAVE_PATH%" /s /q
mkdir "%SAVE_PATH%"
powershell -command "Expand-Archive '!file%pick%!' '%SAVE_PATH%' -Force"
echo Restored!
pause
goto menu

:openfolder
start "" "%BACKUP_PATH%"
goto menu
