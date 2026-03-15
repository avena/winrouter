# WinRouter Troubleshooting Guide

## Overview

This guide helps diagnose and resolve common issues with WinRouter. If you encounter problems, follow the steps below in order.

## Quick Diagnostic Checklist

Before proceeding with specific troubleshooting, run this quick checklist:

```powershell
# Run this diagnostic script
Write-Host "=== WinRouter Diagnostic Check ===" -ForegroundColor Green

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion"

# Check administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Administrator Privileges: $isAdmin"

# Check module loading
try {
    Import-Module "src\WinRouter.psm1" -Force
    Write-Host "Module Loading: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "Module Loading: FAILED - $($_.Exception.Message)" -ForegroundColor Red
}

# Check network adapters
$adapters = Get-NetAdapter -ErrorAction SilentlyContinue
Write-Host "Available Network Adapters: $($adapters.Count)"

# Check NAT status
$natRules = Get-NetNat -ErrorAction SilentlyContinue
Write-Host "NAT Rules: $($natRules.Count)"
```

## Common Issues and Solutions

### 1. Permission and Elevation Issues

#### Problem: "Access Denied" or "Operation not permitted"

**Symptoms:**

- Script fails when trying to modify network settings
- Error messages about insufficient privileges
- NAT rules cannot be created or modified

**Solutions:**

1. **Run as Administrator:**

   ```powershell
   # Right-click PowerShell and select "Run as administrator"
   # Or use the built-in elevation function
   Start-Process powershell -ArgumentList "-File `"$PSScriptRoot\start-network.ps1`"" -Verb runAs
   ```

2. **Check UAC Settings:**
   - Open Control Panel > User Accounts > Change User Account Control settings
   - Ensure UAC is not set to "Never notify" (may cause issues)
   - Recommended setting: "Notify me only when apps try to make changes"

3. **Verify Group Policy:**
   ```powershell
   # Check if network configuration is restricted
   gpresult /h policy_report.html
   ```

#### Problem: Self-elevation fails

**Symptoms:**

- Script doesn't automatically elevate
- Stays in non-administrator mode

**Solutions:**

1. **Manual Elevation:**

   ```powershell
   # Close current PowerShell window
   # Open new PowerShell as Administrator
   # Navigate to project directory and run
   .\start-network.ps1
   ```

2. **Check Elevation Function:**
   ```powershell
   # Test the elevation function directly
   . "src\core\Elevation.ps1"
   Test-Admin
   ```

### 2. Module Loading Issues

#### Problem: "Cannot find module" or "Import-Module failed"

**Symptoms:**

- Error when loading WinRouter.psm1
- Individual module files not found
- Functions not available after import

**Solutions:**

1. **Check File Structure:**

   ```powershell
   # Verify all required files exist
   Get-ChildItem -Path "src\" -Recurse -Filter *.ps1
   ```

2. **Check Module Loading Order:**

   ```powershell
   # Test individual module loading
   $modules = @(
       "src\core\Logger.ps1",
       "src\core\Elevation.ps1",
       "src\network\Get-Interfaces.ps1"
   )

   foreach ($module in $modules) {
       try {
           . $module
           Write-Host "✓ Loaded: $module" -ForegroundColor Green
       } catch {
           Write-Host "✗ Failed: $module - $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

3. **Check Path Resolution:**
   ```powershell
   # Verify $PSScriptRoot is working correctly
   Write-Host "Current script root: $PSScriptRoot"
   Write-Host "Expected module path: $PSScriptRoot\core\Logger.ps1"
   Test-Path "$PSScriptRoot\core\Logger.ps1"
   ```

#### Problem: Syntax errors in modules

**Symptoms:**

- Parse errors when loading modules
- Invalid PowerShell syntax

**Solutions:**

1. **Check Syntax:**

   ```powershell
   # Test syntax of individual files
   $files = Get-ChildItem -Path "src\" -Recurse -Filter *.ps1
   foreach ($file in $files) {
       try {
           [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
           Write-Host "✓ Syntax OK: $file" -ForegroundColor Green
       } catch {
           Write-Host "✗ Syntax Error: $file - $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

2. **Use PSScriptAnalyzer:**
   ```powershell
   Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
   Invoke-ScriptAnalyzer -Path "src\" -Severity Error
   ```

### 3. Network Configuration Issues

#### Problem: "Interface not found" or "Invalid interface name"

**Symptoms:**

- Cannot find network adapters
- Interface names don't match expected values
- IP configuration fails

**Solutions:**

1. **List Available Interfaces:**

   ```powershell
   # Get all network adapters
   Get-NetAdapter | Format-Table -AutoSize

   # Get detailed interface information
   Get-NetIPConfiguration | Format-Table -AutoSize
   ```

2. **Check Interface Status:**

   ```powershell
   # Check if interfaces are enabled
   Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}

   # Check for disabled interfaces
   Get-NetAdapter | Where-Object {$_.Status -eq 'Disabled'}
   ```

3. **Use Interface Index Instead of Name:**
   ```powershell
   # Sometimes interface names contain special characters
   # Use the interface index instead
   Get-NetAdapter | Format-Table -Property Name, InterfaceDescription, ifIndex
   ```

#### Problem: IP address conflicts or invalid configuration

**Symptoms:**

- "IP address already in use" errors
- Invalid subnet mask or gateway
- Network connectivity issues after configuration

**Solutions:**

1. **Check IP Address Availability:**

   ```powershell
   # Ping the IP address to check if it's in use
   Test-Connection -ComputerName "192.168.1.100" -Count 1 -Quiet

   # Check ARP table for conflicts
   Get-NetNeighbor | Where-Object {$_.IPAddress -eq "192.168.1.100"}
   ```

2. **Validate IP Configuration:**

   ```powershell
   function Test-IPConfiguration {
       param(
           [string]$IPAddress,
           [string]$SubnetMask,
           [string]$Gateway
       )

       # Validate IP format
       if ($IPAddress -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
           Write-Error "Invalid IP address format: $IPAddress"
           return $false
       }

       # Validate subnet mask
       if ($SubnetMask -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
           Write-Error "Invalid subnet mask format: $SubnetMask"
           return $false
       }

       return $true
   }
   ```

3. **Check Network Topology:**

   ```powershell
   # View routing table
   Get-NetRoute | Format-Table -AutoSize

   # Check for conflicting routes
   Get-NetRoute | Where-Object {$_.DestinationPrefix -like "192.168.*"}
   ```

### 4. NAT and Port Forwarding Issues

#### Problem: NAT rules not working or not created

**Symptoms:**

- NAT rules appear to be created but don't work
- Port forwarding rules not functioning
- External connections fail

**Solutions:**

1. **Check NAT Configuration:**

   ```powershell
   # View existing NAT rules
   Get-NetNat | Format-Table -AutoSize

   # View NAT external addresses
   Get-NetNatExternalAddress | Format-Table -AutoSize

   # View NAT sessions
   Get-NetNatSession | Format-Table -AutoSize
   ```

2. **Verify IP Forwarding:**

   ```powershell
   # Check if IP forwarding is enabled
   Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter"

   # Enable IP forwarding if needed
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IPEnableRouter" -Value 1
   ```

3. **Test Port Forwarding:**

   ```powershell
   # View port proxy rules
   netsh interface portproxy show all

   # Test connection to forwarded port
   Test-NetConnection -ComputerName "localhost" -Port 8080
   ```

#### Problem: Port conflicts

**Symptoms:**

- "Port already in use" errors
- Cannot bind to specific ports
- Services conflict with each other

**Solutions:**

1. **Check Port Usage:**

   ```powershell
   # View listening ports
   Get-NetTCPConnection -State Listen | Format-Table -AutoSize

   # Check specific port
   Get-NetTCPConnection -LocalPort 80 | Format-Table -AutoSize
   ```

2. **Find Process Using Port:**

   ```powershell
   # Get process using specific port
   $port = 80
   $processId = (Get-NetTCPConnection -LocalPort $port).OwningProcess
   Get-Process -Id $processId | Format-Table -AutoSize
   ```

3. **Use Alternative Ports:**
   ```powershell
   # Common alternative ports
   # HTTP: 8080, 8888, 9000
   # SSH: 2222, 22222
   # Custom: 10000-65535
   ```

### 5. Docker Integration Issues

#### Problem: Docker networks not detected

**Symptoms:**

- Docker networks not showing in WinRouter
- Cannot configure NAT for Docker
- Docker containers cannot access external networks

**Solutions:**

1. **Check Docker Installation:**

   ```powershell
   # Verify Docker is running
   Get-Service com.docker.service

   # Check Docker networks
   docker network ls

   # Get detailed network information
   docker network inspect bridge
   ```

2. **Check Docker Network Configuration:**

   ```powershell
   # View Docker network details
   docker network inspect bridge | ConvertFrom-Json

   # Check if Docker bridge network exists
   $dockerNetworks = docker network ls --format "table {{.Name}}\t{{.ID}}\t{{.Driver}}"
   $dockerNetworks
   ```

3. **Configure Docker NAT:**

   ```powershell
   # Create NAT for Docker bridge network
   New-NetNat -Name "DockerNAT" -InternalIPInterfaceAddressPrefix "172.17.0.0/16"

   # Verify NAT creation
   Get-NetNat | Where-Object {$_.Name -eq "DockerNAT"}
   ```

### 6. Logging and Debugging Issues

#### Problem: No log files created or logs not helpful

**Symptoms:**

- Log files are empty or missing
- Error messages don't provide enough detail
- Cannot trace execution flow

**Solutions:**

1. **Enable Debug Mode:**

   ```powershell
   # Set debug environment variable
   $env:WINROUTER_DEBUG = $true

   # Run script with verbose output
   $VerbosePreference = 'Continue'
   .\start-network.ps1
   ```

2. **Check Log Directory:**

   ```powershell
   # Verify log directory exists and is writable
   $logDir = "logs"
   if (-not (Test-Path $logDir)) {
       New-Item -ItemType Directory -Path $logDir
   }

   # Check log file permissions
   Get-Acl $logDir | Format-List
   ```

3. **Manual Logging:**
   ```powershell
   # Add manual logging to troubleshoot
   function Write-DebugLog {
       param(
           [string]$Message,
           [string]$Level = "INFO"
       )

       $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
       $logEntry = "[$timestamp] [$Level] $Message"

       Write-Host $logEntry
       Add-Content -Path "logs\debug.log" -Value $logEntry
   }
   ```

## Advanced Troubleshooting

### 1. System-Level Diagnostics

```powershell
# Collect comprehensive system information
function Get-WinRouterDiagnostics {
    Write-Host "=== System Information ==="
    Get-ComputerInfo | Select-Object OSName, OSVersion, OSArchitecture, CsManufacturer, CsModel

    Write-Host "`n=== Network Configuration ==="
    Get-NetAdapter | Format-Table -AutoSize
    Get-NetIPConfiguration | Format-Table -AutoSize

    Write-Host "`n=== NAT Configuration ==="
    Get-NetNat | Format-Table -AutoSize
    Get-NetNatExternalAddress | Format-Table -AutoSize

    Write-Host "`n=== Firewall Status ==="
    Get-NetFirewallProfile | Format-Table -AutoSize

    Write-Host "`n=== Event Logs (Recent Network Events) ==="
    Get-WinEvent -LogName "System" -MaxEvents 10 | Where-Object {$_.Message -match "network|adapter|ip"} | Format-Table TimeCreated, Id, Message -AutoSize
}

Get-WinRouterDiagnostics
```

### 2. Network Connectivity Testing

```powershell
# Comprehensive connectivity test
function Test-WinRouterConnectivity {
    param(
        [string]$TargetIP = "8.8.8.8",
        [int]$TargetPort = 53
    )

    Write-Host "Testing connectivity to $TargetIP:$TargetPort"

    # Test basic connectivity
    $pingResult = Test-Connection -ComputerName $TargetIP -Count 3 -Quiet
    Write-Host "Ping test: $pingResult"

    # Test port connectivity
    $tcpTest = Test-NetConnection -ComputerName $TargetIP -Port $TargetPort
    Write-Host "TCP test: $($tcpTest.TcpTestSucceeded)"

    # Test DNS resolution
    try {
        $dnsResult = Resolve-DnsName "google.com"
        Write-Host "DNS resolution: SUCCESS"
    } catch {
        Write-Host "DNS resolution: FAILED - $($_.Exception.Message)"
    }
}

Test-WinRouterConnectivity
```

### 3. Performance and Resource Monitoring

```powershell
# Monitor system resources during WinRouter operations
function Start-WinRouterMonitoring {
    Write-Host "Starting resource monitoring..."

    # Monitor CPU and memory
    $monitorScript = {
        while ($true) {
            $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
            $memory = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
            $timestamp = Get-Date -Format "HH:mm:ss"

            Write-Host "[$timestamp] CPU: $([math]::Round($cpu,2))% Memory: $memory MB"
            Start-Sleep 5
        }
    }

    $monitorJob = Start-Job -ScriptBlock $monitorScript

    # Return job object for cleanup
    return $monitorJob
}

# Usage:
$monitor = Start-WinRouterMonitoring
# Run your WinRouter operations here
Stop-Job $monitor
Remove-Job $monitor
```

## Getting Help

### 1. Collect Diagnostic Information

Before reporting an issue, collect this information:

```powershell
# Create diagnostic package
$diagnosticDir = "winrouter-diagnostics"
New-Item -ItemType Directory -Path $diagnosticDir -Force | Out-Null

# System information
Get-ComputerInfo | Out-File "$diagnosticDir\system-info.txt"

# Network configuration
Get-NetAdapter | Out-File "$diagnosticDir\network-adapters.txt"
Get-NetIPConfiguration | Out-File "$diagnosticDir\ip-configuration.txt"

# NAT configuration
Get-NetNat | Out-File "$diagnosticDir\nat-rules.txt"
Get-NetNatExternalAddress | Out-File "$diagnosticDir\nat-external.txt"

# Event logs
Get-WinEvent -LogName "System" -MaxEvents 50 | Where-Object {$_.Message -match "network|adapter|ip|nat"} | Out-File "$diagnosticDir\event-logs.txt"

# WinRouter logs
Copy-Item "logs\*" "$diagnosticDir\" -Force -ErrorAction SilentlyContinue

# Create archive
Compress-Archive -Path $diagnosticDir -DestinationPath "winrouter-diagnostics.zip" -Force
```

### 2. Report Issues

When reporting issues:

1. **Include diagnostic information** from the steps above
2. **Describe the problem** clearly with expected vs. actual behavior
3. **Provide reproduction steps** that consistently trigger the issue
4. **Include error messages** exactly as they appear
5. **Specify your environment**: Windows version, PowerShell version, network setup

### 3. Common Workarounds

#### Reset Network Configuration

```powershell
# Reset TCP/IP stack
netsh int ip reset resetlog.txt

# Reset Winsock
netsh winsock reset

# Restart network services
Restart-Service -Name "Dnscache" -Force
Restart-Service -Name "Netman" -Force
```

#### Clear NAT Rules

```powershell
# Remove all NAT rules
Get-NetNat | Remove-NetNat -Confirm:$false

# Remove all port proxy rules
netsh interface portproxy reset
```

#### Rebuild WinRouter Modules

```powershell
# Clear module cache
Remove-Module -Name WinRouter -Force -ErrorAction SilentlyContinue

# Rebuild module from scratch
Import-Module "src\WinRouter.psm1" -Force
```

This troubleshooting guide covers the most common issues with WinRouter. If you cannot resolve your problem using these steps, please collect the diagnostic information and report the issue with detailed information about your environment and the problem you're experiencing.
