#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# 1. Elevation and Core
Write-Host "WinRouter - Network & NAT Management" -ForegroundColor Cyan
Write-Host "Running as Administrator." -ForegroundColor Green
Write-Host ""

# Initialize logging system
Write-Host "Initializing logging system..." -ForegroundColor Gray
. "$PSScriptRoot\src\core\Logger.ps1"
Write-Section "WinRouter Script Initialization"
Write-Log "Starting WinRouter network configuration script" "INFO"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" "DEBUG"
Write-Log "Script path: $PSScriptRoot" "DEBUG"
Write-Log "Log file: $Global:LogFile" "DEBUG"

# Elevation check
Write-Log "Checking administrator privileges..." "INFO"
. "$PSScriptRoot\src\core\Elevation.ps1"
Ensure-Admin
Write-Log "Administrator privileges confirmed" "SUCCESS"

# 2. Load Modules
Write-Log "Loading network modules..." "INFO"
. "$PSScriptRoot\src\network\Get-Interfaces.ps1"
Write-Log "✓ Get-Interfaces module loaded" "SUCCESS"
. "$PSScriptRoot\src\network\Set-StaticIP.ps1"
Write-Log "✓ Set-StaticIP module loaded" "SUCCESS"
. "$PSScriptRoot\src\network\Remove-StaticIP.ps1"
Write-Log "✓ Remove-StaticIP module loaded" "SUCCESS"

Write-Log "Loading NAT modules..." "INFO"
. "$PSScriptRoot\src\nat\Get-NatStatus.ps1"
Write-Log "✓ Get-NatStatus module loaded" "SUCCESS"
. "$PSScriptRoot\src\nat\New-NatRule.ps1"
Write-Log "✓ New-NatRule module loaded" "SUCCESS"
. "$PSScriptRoot\src\nat\Remove-NatRule.ps1"
Write-Log "✓ Remove-NatRule module loaded" "SUCCESS"
. "$PSScriptRoot\src\nat\Test-NatPrerequisites.ps1"
Write-Log "✓ Test-NatPrerequisites module loaded" "SUCCESS"
Write-Log "All modules loaded successfully" "SUCCESS"

# 3. Get Interfaces and NAT status
Write-Log "Starting interface discovery and NAT status check..." "INFO"
Write-Log "Calling Get-WinRouterInterfaces function..." "INFO"
$interfaces = Get-WinRouterInterfaces
Write-Log "Interface discovery complete. Found $($interfaces.Count) interfaces" "SUCCESS"

Write-Log "Checking NAT rules status..." "INFO"
$nats = Get-WinRouterNatRules
Write-Log "NAT status check complete. Found $($nats.Count) NAT rules" "INFO"

if ($interfaces.Count -eq 0) {
    Write-Warning "No suitable network interfaces found."
    Write-Log "ERROR: No suitable network interfaces found. Exiting script." "ERROR"
    exit
}

# Display Global NAT Status
Write-Log "Displaying system NAT status..." "INFO"
Write-Host ""
if ($nats.Count -gt 0) {
    Write-Host ">>> SYSTEM NAT STATUS: ACTIVE ($($nats.Count) rules found)" -ForegroundColor Green
    foreach ($n in $nats) {
        Write-Host "    * $($n.Name): $($n.InternalIPInterfaceAddressPrefix)" -ForegroundColor Green
        Write-Log "Active NAT rule: $($n.Name) -> $($n.InternalIPInterfaceAddressPrefix)" "INFO"
    }
}
else {
    Write-Host ">>> SYSTEM NAT STATUS: INACTIVE (No NAT rules active)" -ForegroundColor Yellow
    Write-Log "No active NAT rules found" "INFO"
}
Write-Host ""

# 4. Display Table
Write-Log "Displaying interface table..." "INFO"
$interfaces | Format-Table Selection, Name, IP, GatewayStatus, NAT, Status -AutoSize
Write-Log "Interface table display complete" "SUCCESS"

# 5. User Selection: WAN and LAN
Write-Log "Starting user interface selection process..." "INFO"
Write-Log "Prompting user for WAN interface selection..." "INFO"
$wanSelectionInput = Read-Host "Select WAN Interface (Letter)"
Write-Log "User selected WAN interface: $wanSelectionInput" "INFO"

Write-Log "Prompting user for LAN interface selection..." "INFO"
$lanSelectionInput = Read-Host "Select LAN Interface (Letter)"
Write-Log "User selected LAN interface: $lanSelectionInput" "INFO"

Write-Log "Validating user selections..." "INFO"
$wanInterface = $interfaces | Where-Object { $_.Selection -eq $wanSelectionInput.ToUpper() }
$lanInterface = $interfaces | Where-Object { $_.Selection -eq $lanSelectionInput.ToUpper() }

if (-not $wanInterface -or -not $lanInterface) {
    Write-Error "Invalid selection."
    Write-Log "ERROR: Invalid interface selection. WAN: $wanSelectionInput, LAN: $lanSelectionInput" "ERROR"
    exit
}

Write-Log "Interface validation successful" "SUCCESS"
Write-Log "WAN Interface: $($wanInterface.Name) (IP: $($wanInterface.IP))" "INFO"
Write-Log "LAN Interface: $($lanInterface.Name) (IP: $($lanInterface.IP))" "INFO"

Write-Host ""
Write-Host "Selected WAN : $($wanInterface.Name) (IP: $($wanInterface.IP))" -ForegroundColor Yellow
Write-Host "Selected LAN : $($lanInterface.Name) (IP: $($lanInterface.IP))" -ForegroundColor Yellow
Write-Host ""

# 6. LAN IP Configuration Choice
Write-Log "Starting IP configuration selection process..." "INFO"
Write-Host "=== IP CONFIGURATION ===" -ForegroundColor Cyan
Write-Host "S) Set Static IP (.1)"
Write-Host "R) Remove Static IP / Enable Dynamic (DHCP)"
Write-Host "K) Keep current configuration"
$ipChoice = (Read-Host "Selection (S, R, or K)").ToUpper()
Write-Log "User selected IP configuration option: $ipChoice" "INFO"

$currentBase = "50" # Default base

switch ($ipChoice) {
    "S" {
        Write-Log "User selected: Set Static IP configuration" "INFO"
        Write-Host "Select LAN Network Base:" -ForegroundColor Cyan
        Write-Host "1) 192.168.50.x"
        Write-Host "2) 192.168.60.x"
        Write-Host "3) 192.168.70.x"
        $netChoice = Read-Host "Choice (1, 2, or 3, default 1)"
        Write-Log "User selected network base: $netChoice" "INFO"

        $currentBase = switch ($netChoice) {
            "1" { "50" }
            "2" { "60" }
            "3" { "70" }
            Default { "50" }
        }

        Write-Log "Setting current network base to: $currentBase" "INFO"
        $lanIP = "192.168.$currentBase.1"
        Write-Log "Configuring static IP: $lanIP on interface $($lanInterface.Name)" "INFO"
        Set-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex -IPAddress $lanIP -PrefixLength 24
        Write-Log "Static IP configuration completed" "SUCCESS"
    }
    "R" {
        Write-Log "User selected: Remove Static IP / Enable DHCP" "INFO"
        Write-Log "Removing static IP configuration from interface $($lanInterface.Name)" "INFO"
        Remove-WinRouterStaticIP -InterfaceIndex $lanInterface.InterfaceIndex
        Write-Log "Static IP removal completed" "SUCCESS"
    }
    Default {
        Write-Log "User selected: Keep current IP configuration" "INFO"
        Write-Host "Skipping IP modification." -ForegroundColor Gray
        if ($lanInterface.IP -match '192\.168\.(\d+)\.') { $currentBase = $matches[1] }
        Write-Log "Detected current network base: $currentBase" "INFO"
    }
}

# 7. NAT Configuration Choice
Write-Log "Starting NAT configuration selection process..." "INFO"
Write-Host ""
Write-Host "=== NAT CONFIGURATION ===" -ForegroundColor Cyan
Write-Host "S) Set NAT Rules (LAN to WAN)"
Write-Host "R) Remove NAT Rules"
Write-Host "K) Keep current configuration"
$natChoice = (Read-Host "Selection (S, R, or K)").ToUpper()
Write-Log "User selected NAT configuration option: $natChoice" "INFO"

switch ($natChoice) {
    "S" {
        Write-Log "User selected: Set NAT Rules configuration" "INFO"

        # Set NAT rule for the current LAN prefix
        $prefix = "192.168.$currentBase.0/24"
        $natName = "NAT-WinRouter-$currentBase"

        Write-Log "Creating NAT rule: $natName for prefix: $prefix" "INFO"
        try {
            New-WinRouterNatRule -Name $natName -InternalIPInterfaceAddressPrefix $prefix
            Write-Host "NAT criado com sucesso!" -ForegroundColor Green
            Write-Log "NAT rule creation successful: $natName" "SUCCESS"
        }
        catch {
            Write-Error "Falha ao criar NAT: $($_.Exception.Message)"
            Write-Log "ERROR: NAT rule creation failed: $($_.Exception.Message)" "ERROR"
            Write-Host "Solução: Reinicie o sistema e tente novamente." -ForegroundColor Yellow
        }
    }
    "R" {
        Write-Log "User selected: Remove NAT Rules" "INFO"
        # Remove NAT rules
        Write-Log "Checking for existing NAT rules..." "INFO"
        $natRules = Get-WinRouterNatRules
        if (-not $natRules) {
            Write-Host "No NAT rules found to remove." -ForegroundColor Yellow
            Write-Log "No NAT rules found for removal" "INFO"
            break
        }

        Write-Log "Found $($natRules.Count) NAT rules for potential removal" "INFO"
        $confirmRemove = Read-Host "Remove ALL NAT rules? (Y/N)"
        Write-Log "User confirmation for NAT removal: $confirmRemove" "INFO"
        
        if ($confirmRemove -match '^[Yy]') {
            Write-Log "Removing all NAT rules using Clean Slate method..." "INFO"
            Write-Host "Removing all NAT rules..." -ForegroundColor Cyan
            Remove-WinRouterNatRule -Description "User requested ALL removal"
            Write-Log "All NAT rules removal completed" "SUCCESS"
        }
        else {
            Write-Log "User chose selective NAT rule removal" "INFO"
            Write-Host "Active NAT rules:"
            for ($i = 0; $i -lt $natRules.Count; $i++) {
                Write-Host "$($i+1)) $($natRules[$i].Name) ($($natRules[$i].InternalIPInterfaceAddressPrefix))"
            }
            $ruleIdxStr = Read-Host "Number to remove (or Enter to cancel)"
            Write-Log "User selected rule index: $ruleIdxStr" "INFO"
            
            if ([int]::TryParse($ruleIdxStr, [ref]$ruleIdx) -and $ruleIdx -ge 1 -and $ruleIdx -le $natRules.Count) {
                $ruleToRemove = $natRules[[int]$ruleIdx - 1]
                Write-Log "Removing selected NAT rule: $($ruleToRemove.Name) (Note: Clean Slate will remove ALL)" "INFO"
                Remove-WinRouterNatRule -Description "Selected rule: $($ruleToRemove.Name)"
                Write-Log "Selected NAT rule removal completed" "SUCCESS"
            }
            else {
                Write-Host "Invalid selection or cancellation. No rules removed." -ForegroundColor Gray
                Write-Log "Invalid rule selection or cancellation" "INFO"
            }
        }
    }
    Default {
        Write-Log "User selected: Keep current NAT configuration" "INFO"
        Write-Host "Skipping NAT modification." -ForegroundColor Gray
    }
}

# 8. Final Steps
Write-Log "Starting final configuration steps..." "INFO"
Write-Log "Enabling IP forwarding..." "INFO"
Enable-IPForwarding
Write-Log "IP forwarding enabled successfully" "SUCCESS"

Write-Log "Generating final status report..." "INFO"
Write-Host ""
Write-Host "--- Final Status ---" -ForegroundColor Green
Write-Host "WAN Interface : $($wanInterface.Name)"
Write-Host "LAN Interface : $($lanInterface.Name) (IP: $( (Get-NetIPAddress -InterfaceIndex $lanInterface.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress ))"
Write-Host "IP Forwarding : $(if (Get-IPForwardingStatus) { 'ENABLED' } else { 'DISABLED' })"

Write-Log "Checking final NAT rules status..." "INFO"
$finalNats = @(Get-NetNat -ErrorAction SilentlyContinue | Where-Object { $_.Active -eq $true })
$phantomNats = @(Get-NetNat -ErrorAction SilentlyContinue | Where-Object { $_.Active -eq $false })

if ($finalNats.Count -gt 0) {
    Write-Host "Active NAT    : $($finalNats.Name -join ', ')"
    Write-Log "Final NAT status: $($finalNats.Count) active rules" "INFO"
    foreach ($nat in $finalNats) {
        Write-Log "Final NAT rule: $($nat.Name) -> $($nat.InternalIPInterfaceAddressPrefix)" "INFO"
    }
}
else {
    Write-Host "Active NAT    : NONE"
    Write-Log "Final NAT status: No active rules" "INFO"
}

if ($phantomNats.Count -gt 0) {
    $phantomNames = ($phantomNats | Select-Object -ExpandProperty Name) -join ', '
    Write-Host "Phantom NAT   : $phantomNames" -ForegroundColor Yellow
    Write-Log "Regras fantasma (Active=False, pendente reboot): $phantomNames" "WARN"
}

# Status final honesto
$overallSuccess = ($finalNats.Count -gt 0) -and ($phantomNats.Count -eq 0)
if ($overallSuccess) {
    Write-Log "Configuration process completed successfully" "SUCCESS"
}
else {
    Write-Log "Configuration INCOMPLETE: reboot necessario para limpar estado." "WARN"
}

Write-Host ""
Write-Host "Configuration Complete. Internet sharing should be active." -ForegroundColor Green
Write-Log "Script execution completed. Waiting for user to exit..." "INFO"
Read-Host "Press Enter to exit..."
Write-Log "User exited script" "INFO"
