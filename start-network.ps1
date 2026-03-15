#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# 1. Elevation
. "$PSScriptRoot\src\core\Elevation.ps1"
Ensure-Admin

Write-Host "WinRouter MVP - Interface Selection" -ForegroundColor Cyan
Write-Host "Running as Administrator." -ForegroundColor Green
Write-Host ""

# 2. Load Modules
. "$PSScriptRoot\src\network\Get-Interfaces.ps1"

# 3. Get Interfaces
Write-Host "Discovering interfaces..." -ForegroundColor Gray
$interfaces = Get-WinRouterInterfaces

if ($interfaces.Count -eq 0) {
    Write-Warning "No suitable network interfaces found."
    exit
}

# 4. Display Table
$interfaces | Format-Table Selection, Name, IP, GatewayStatus, NAT, Status -AutoSize

# 5. User Selection
$wanSelection = Read-Host "Select WAN Interface (Letter)"
$lanSelection = Read-Host "Select LAN Interface(s) (Letter, separate with space)"

# 6. Resolve Selection
$wanInterface = $interfaces | Where-Object { $_.Selection -eq $wanSelection }
$lanInterfaces = $interfaces | Where-Object { $lanSelection -split ' ' -contains $_.Selection }

Write-Host ""
Write-Host "--- Selection Summary ---" -ForegroundColor Cyan

if (-not $wanInterface) {
    Write-Error "Invalid WAN selection."
} else {
    Write-Host "WAN : $($wanInterface.Name)" -ForegroundColor Yellow
    Write-Host "      IP: $($wanInterface.IP)" -ForegroundColor Gray
}

if (-not $lanInterfaces) {
    Write-Error "Invalid LAN selection."
} else {
    foreach ($lan in $lanInterfaces) {
        Write-Host "LAN : $($lan.Name)" -ForegroundColor Yellow
        Write-Host "      IP: $($lan.IP)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "MVP Check Complete." -ForegroundColor Green
Read-Host "Press Enter to exit..."
