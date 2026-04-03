@echo off
setlocal enabledelayedexpansion
title Everwind Backup Manager
color 0A

:: =========================
:: ADMIN CHECK (UNCHANGED)
:: =========================
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] This script must be run as Administrator!
    echo.
    echo Right-click this file and select:
    echo "Run as administrator"
    echo.
    pause
    exit /b
)

:: =========================
:: VARIABLES
:: =========================
set SCRIPT_PATH=C:\Scripts
set SCRIPT_FILE=%SCRIPT_PATH%\everwind_backup.ps1
set TASK_NAME=Everwind Backup

:menu
cls
echo =============================
echo   EVERWIND BACKUP MANAGER
echo =============================
echo.
echo 1. Install Backup System
echo 2. Uninstall Backup System
echo 3. Restore Backup
echo 4. Open Backup Folder
echo 5. Exit
echo.
set /p choice=Choose an option: 

if "%choice%"=="1" goto install
if "%choice%"=="2" goto uninstall
if "%choice%"=="3" goto restore
if "%choice%"=="4" goto openfolder
if "%choice%"=="5" exit
goto menu

:: =========================
:: INSTALL (UNCHANGED)
:: =========================
:install
cls
echo Setting up Everwind backup...

mkdir %SCRIPT_PATH% >nul 2>&1

echo $ErrorActionPreference = "SilentlyContinue" > %SCRIPT_FILE%
echo if (-not (Get-Process Everwind -ErrorAction SilentlyContinue)) { exit } >> %SCRIPT_FILE%
echo $user = (Get-CimInstance Win32_ComputerSystem).UserName >> %SCRIPT_FILE%
echo if (-not $user) { exit } >> %SCRIPT_FILE%
echo $userName = $user.Split('\')[-1] >> %SCRIPT_FILE%
echo $basePath = "C:\Users\$userName\AppData\Local\Everwind\Saved" >> %SCRIPT_FILE%
echo $source = "$basePath\SaveGames" >> %SCRIPT_FILE%
echo $backupRoot = "$basePath\Backups" >> %SCRIPT_FILE%
echo $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm" >> %SCRIPT_FILE%
echo $zipPath = "$backupRoot\Everwind_$timestamp.zip" >> %SCRIPT_FILE%
echo if (!(Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot ^| Out-Null } >> %SCRIPT_FILE%
echo Compress-Archive -Path "$source\*" -DestinationPath $zipPath -Force >> %SCRIPT_FILE%
echo Get-ChildItem $backupRoot -Filter *.zip ^| Sort-Object CreationTime -Descending ^| Select-Object -Skip 3 ^| Remove-Item -Force >> %SCRIPT_FILE%

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

schtasks /create ^
/tn "%TASK_NAME%" ^
/sc hourly ^
/mo 1 ^
/st 00:00 ^
/tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File %SCRIPT_FILE%" ^
/ru SYSTEM ^
/rl highest ^
/f

echo.
echo [OK] Backup installed!
echo Running first backup now...
schtasks /run /tn "%TASK_NAME%"

echo.
pause
goto menu

:: =========================
:: UNINSTALL (NEW)
:: =========================
:uninstall
cls
echo Removing Everwind backup...

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

if exist "%SCRIPT_FILE%" del "%SCRIPT_FILE%" /f /q
rmdir %SCRIPT_PATH% >nul 2>&1

echo.
echo [OK] Backup system removed.
echo.
pause
goto menu

:: =========================
:: RESTORE (NEW)
:: =========================
:restore
cls
echo Locating backups...

for /f "tokens=2 delims=\" %%a in ('whoami') do set USERNAME=%%a

set BASE_PATH=C:\Users\%USERNAME%\AppData\Local\Everwind\Saved
set BACKUP_PATH=%BASE_PATH%\Backups
set SAVE_PATH=%BASE_PATH%\SaveGames

if not exist "%BACKUP_PATH%" (
    echo No backups found!
    pause
    goto menu
)

echo.
echo Available backups:
echo ----------------------

set count=0
for /f "delims=" %%f in ('dir /b /o-d "%BACKUP_PATH%\*.zip"') do (
    set /a count+=1
    echo !count!. %%f
    set "file!count!=%BACKUP_PATH%\%%f"
)

if %count%==0 (
    echo No backup files found!
    pause
    goto menu
)

echo.
set /p pick=Select backup number: 

if not defined file%pick% (
    echo Invalid selection!
    pause
    goto menu
)

echo.
echo WARNING: This will overwrite your current SaveGames!
set /p confirm=Type YES to continue: 

if /I not "%confirm%"=="YES" goto menu

echo Restoring backup...

rmdir "%SAVE_PATH%" /s /q >nul 2>&1
mkdir "%SAVE_PATH%" >nul 2>&1

powershell -command "Expand-Archive -Path '!file%pick%!' -DestinationPath '%SAVE_PATH%' -Force"

echo.
echo [OK] Backup restored successfully!
echo.
pause
goto menu

:: =========================
:: OPEN BACKUP FOLDER (NEW)
:: =========================
:openfolder
cls
echo Opening backup folder...

for /f "tokens=2 delims=\" %%a in ('whoami') do set USERNAME=%%a

set BASE_PATH=C:\Users\%USERNAME%\AppData\Local\Everwind\Saved
set BACKUP_PATH=%BASE_PATH%\Backups

if not exist "%BACKUP_PATH%" (
    echo Backup folder does not exist yet!
    pause
    goto menu
)

start "" "%BACKUP_PATH%"

goto menu
