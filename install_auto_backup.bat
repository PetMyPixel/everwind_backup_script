@echo off
title Everwind Backup Installer

:: --- ADMIN CHECK ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] This installer must be run as Administrator!
    echo.
    echo Right-click this file and select:
    echo "Run as administrator"
    echo.
    pause
    exit /b
)

color 0A

echo Setting up Everwind backup...

:: Define script location
set SCRIPT_PATH=C:\Scripts
set SCRIPT_FILE=%SCRIPT_PATH%\everwind_backup.ps1

:: Create Scripts folder
mkdir %SCRIPT_PATH% >nul 2>&1

:: Create PowerShell script (auto user + silent + keep 3)
echo $ErrorActionPreference = "SilentlyContinue" > %SCRIPT_FILE%
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

:: Remove old task (if exists)
schtasks /delete /tn "Everwind Backup" /f >nul 2>&1

:: Create TRUE hourly scheduled task (FIXED)
schtasks /create ^
/tn "Everwind Backup" ^
/sc hourly ^
/mo 1 ^
/st 00:00 ^
/tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\everwind_backup.ps1" ^
/ru SYSTEM ^
/rl highest ^
/f

echo.
echo [OK] Everwind backup installed successfully!
echo Hourly backup enabled (true hourly, no skipping).
echo Silent mode enabled.
echo Auto user detection enabled.
echo Keeps last 3 backups.
echo.

echo Running first backup now...
schtasks /run /tn "Everwind Backup"

echo.
pause