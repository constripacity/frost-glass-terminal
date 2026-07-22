@echo off
rem Frost Glass — launch the live customizer (WinForms) under PowerShell 7.
where pwsh >nul 2>nul
if errorlevel 1 (
    echo.
    echo PowerShell 7 ^(pwsh^) is required for the customizer.
    echo Install it with:  winget install --id Microsoft.PowerShell -e
    echo.
    pause
    exit /b 1
)
start "" pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0customize.ps1"
