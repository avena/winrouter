#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# 1. Elevation and Core
. "$PSScriptRoot\src\core\Elevation.ps1"
Ensure-Admin

Write-Host "WinRouter - Network & NAT Management" -ForegroundColor Cyan
Write-Host "Running as Administrator." -ForegroundColor Green
Write-Host ""

# 2. Load Modules
. "$PSScriptRoot\src\network\Get-Interfaces.ps1"
. "$PSScriptRoot\src\network\Set-StaticIP.ps1"
. "$PSScriptRoot\src\network\Remove-StaticIP.ps1"
. "$PSScriptRoot\src\nat\Get-NatStatus.ps1"
. "$PSScriptRoot\src\nat\New-NatRule.ps1"
. "$PSScriptRoot\src\nat\Remove-NatRule.ps1"

# 3. Get Interfaces and NAT status
Write-Host "Discovering interfaces and NAT rules..." -ForegroundColor Gray
$interfaces = Get-WinRouterInterfaces
$nats = Get-WinRouterNatRules

if ($interfaces.Count -eq 0) {
    Write-Warning "No suitable network interfaces found."
    exit
}

# Display Global NAT Status
Write-Host ""
if ($nats.Count -gt 0) {
    Write-Host ">>> SYSTEM NAT STATUS: ACTIVE ($($nats.Count) rules found)" -ForegroundColor Green
    foreach ($n in $nats) {
        Write-Host "    * $($n.Name): $($n.InternalIPInterfaceAddressPrefix)" -ForegroundColor Green
    }
} else {
    Write-Host ">>> SYSTEM NAT STATUS: INACTIVE (No NAT rules active)" -ForegroundColor Yellow
}
Write-Host ""

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
Write-Host "=== IP CONFIGURATION ===" -ForegroundColor Cyan
Write-Host "S) Set Static IP (.1)"
Write-Host "R) Remove Static IP / Enable Dynamic (DHCP)"
Write-Host "K) Keep current configuration"
$ipChoice = (Read-Host "Selection (S, R, or K)").ToUpper()

$currentBase = "50" # Default base

switch ($ipChoice) {
    "S" {
        Write-Host "Select LAN Network Base:" -ForegroundColor Cyan
        Write-Host "1) 192.168.50.x"
        Write-Host "2) 192.168.60.x"
        Write-Host "3) 192.168.70.x"
        $netChoice = Read-Host "Choice (1, 2, or 3, default 1)"

        $currentBase = switch ($netChoice) {
            "1" { "50" }
            "2" { "60" }
            "3" { "70" }
            Default { "50" }
        }

        $lanIP = "192.168.$currentBase.1"
        Set-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex -IPAddress $lanIP -PrefixLength 24
    }
    "R" {
        Remove-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex
    }
    Default {
        Write-Host "Skipping IP modification." -ForegroundColor Gray
        if ($lanInterface.IP -match '192\.168\.(\d+)\.') { $currentBase = $matches[1] }
    }
}

# 7. NAT Configuration Choice
Write-Host ""
Write-Host "=== NAT CONFIGURATION ===" -ForegroundColor Cyan
Write-Host "S) Set NAT Rules (LAN to WAN)"
Write-Host "R) Remove NAT Rules"
Write-Host "K) Keep current configuration"
$natChoice = (Read-Host "Selection (S, R, or K)").ToUpper()

switch ($natChoice) {
    "S" {
        # Set NAT rule for the current LAN prefix
        $prefix = "192.168.$currentBase.0/24"
        $natName = "NAT-WinRouter-$currentBase"
        New-WinRouterNatRule -Name $natName -InternalIPInterfaceAddressPrefix $prefix
    }
    "R" {
        # Remove NAT rules
        $natRules = Get-WinRouterNatRules
        if (-not $natRules) {
            Write-Host "No NAT rules found to remove." -ForegroundColor Yellow
            break
        }

        $confirmRemove = Read-Host "Remove ALL NAT rules? (Y/N)"
        if ($confirmRemove -match '^[Yy]') {
            Write-Host "Removing all NAT rules..." -ForegroundColor Cyan
            foreach ($rule in $natRules) {
                Remove-WinRouterNatRule -NatRule $rule
            }
        } else {
            Write-Host "Active NAT rules:"
            for ($i=0; $i -lt $natRules.Count; $i++) {
                Write-Host "$($i+1)) $($natRules[$i].Name) ($($natRules[$i].InternalIPInterfaceAddressPrefix))"
            }
            $ruleIdxStr = Read-Host "Number to remove (or Enter to cancel)"
            if ([int]::TryParse($ruleIdxStr, [ref]$ruleIdx) -and $ruleIdx -ge 1 -and $ruleIdx -le $natRules.Count) {
                $ruleToRemove = $natRules[[int]$ruleIdx - 1]
                Remove-WinRouterNatRule -NatRule $ruleToRemove
            } else {
                Write-Host "Invalid selection or cancellation. No rules removed." -ForegroundColor Gray
            }
        }
    }
    Default {
        Write-Host "Skipping NAT modification." -ForegroundColor Gray
    }
}

# 8. Final Steps
Enable-IPForwarding

Write-Host ""
Write-Host "--- Final Status ---" -ForegroundColor Green
Write-Host "WAN Interface : $($wanInterface.Name)"
Write-Host "LAN Interface : $($lanInterface.Name) (IP: $( (Get-NetIPAddress -InterfaceIndex $lanInterface.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress ))"
Write-Host "IP Forwarding : $(if (Get-IPForwardingStatus) { 'ENABLED' } else { 'DISABLED' })"

$finalNats = Get-WinRouterNatRules
if ($finalNats) {
    Write-Host "Active NAT    : $($finalNats.Name -join ', ')"
} else {
    Write-Host "Active NAT    : NONE"
}

Write-Host ""
Write-Host "Configuration Complete. Internet sharing should be active." -ForegroundColor Green
Read-Host "Press Enter to exit..."
