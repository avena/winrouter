#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# 1. Elevation and Core
. "$PSScriptRoot\src\core\Elevation.ps1"
Ensure-Admin

Write-Host "WinRouter - IP Management" -ForegroundColor Cyan
Write-Host "Running as Administrator." -ForegroundColor Green
Write-Host ""

# 2. Load Modules
. "$PSScriptRoot\src\network\Get-Interfaces.ps1"
. "$PSScriptRoot\src\network\Set-StaticIP.ps1"
. "$PSScriptRoot\src\network\Remove-StaticIP.ps1"

# 3. Get Interfaces
Write-Host "Discovering interfaces..." -ForegroundColor Gray
$interfaces = Get-WinRouterInterfaces

if ($interfaces.Count -eq 0) {
    Write-Warning "No suitable network interfaces found."
    exit
}

# 4. Display Table
$interfaces | Format-Table Selection, Name, IP, GatewayStatus, NAT, Status -AutoSize

# 5. User Selection: WAN and LAN
$wanSelectionInput = Read-Host "Select WAN Interface (Letter)"
$lanSelectionInput = Read-Host "Select LAN Interface (Letter)"

$wanInterface = $interfaces | Where-Object { $_.Selection -eq $wanSelectionInput.ToUpper() }
$lanInterface = $interfaces | Where-Object { $_.Selection -eq $lanSelectionInput.ToUpper() }

if (-not $wanInterface -or -not $lanInterface) {
    Write-Error "Invalid selection."
    exit
}

Write-Host ""
Write-Host "Selected WAN : $($wanInterface.Name) (IP: $($wanInterface.IP))" -ForegroundColor Yellow
Write-Host "Selected LAN : $($lanInterface.Name) (IP: $($lanInterface.IP))" -ForegroundColor Yellow
Write-Host ""

# 6. LAN IP Configuration Choice
Write-Host "Choose IP Configuration for LAN ($($lanInterface.Name)):" -ForegroundColor Cyan
Write-Host "S) Set Static IP (.1)"
Write-Host "R) Remove Static IP / Enable Dynamic (DHCP)"
Write-Host "K) Keep current configuration"
$ipChoice = (Read-Host "Selection (S, R, or K)").ToUpper()

switch ($ipChoice) {
    "S" {
        # Static IP Logic
        Write-Host "Select LAN Network Base:" -ForegroundColor Cyan
        Write-Host "1) 192.168.50.x"
        Write-Host "2) 192.168.60.x"
        Write-Host "3) 192.168.70.x"
        $netChoice = Read-Host "Choice (1, 2, or 3, default 1)"

        $base = switch ($netChoice) {
            "1" { "50" }
            "2" { "60" }
            "3" { "70" }
            Default { "50" }
        }

        $lanIP = "192.168.$base.1"
        Set-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex -IPAddress $lanIP -PrefixLength 24
    }
    "R" {
        # Dynamic/DHCP Logic
        Remove-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex
    }
    "K" {
        Write-Host "Skipping LAN IP configuration." -ForegroundColor Gray
    }
    Default {
        Write-Warning "No valid selection made. Skipping IP configuration."
    }
}

# 7. Enable Forwarding
Enable-IPForwarding

Write-Host ""
Write-Host "--- Status Summary ---" -ForegroundColor Green
Write-Host "WAN Interface: $($wanInterface.Name)"
Write-Host "LAN Interface: $($lanInterface.Name)"
Write-Host "IP Forwarding: $(if (Get-IPForwardingStatus) { 'ENABLED' } else { 'DISABLED' })"

Write-Host ""
Write-Host "Next Step: Configure NAT rules (future module)." -ForegroundColor Yellow
Read-Host "Press Enter to exit..."
