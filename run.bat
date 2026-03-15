@echo off
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
    echo PowerShell 7 nao encontrado.
    echo Instale via: winget install Microsoft.PowerShell
    pause
    exit /b 1
)

pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-network.ps1"
pause
