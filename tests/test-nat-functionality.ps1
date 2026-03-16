# WinRouter NAT Functionality Test Script

# Import the main module
try {
  Import-Module "$PSScriptRoot\src\WinRouter.psm1" -Force -ErrorAction Stop
  Write-Host "Main module loaded successfully." -ForegroundColor Green
}
catch {
  Write-Host "Error loading main module: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# Test 1: Check if IPv4 is supported
Write-Host "=== IPv4 Support Test ===" -ForegroundColor Cyan
try {
  $ipv4Test = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
  if ($ipv4Test) {
    Write-Host "IPv4 is supported on this system." -ForegroundColor Green
  }
  else {
    Write-Host "IPv4 is NOT supported on this system." -ForegroundColor Red
  }
}
catch {
  Write-Host "Error checking IPv4 support: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Test NAT rule creation
Write-Host "`n=== NAT Rule Creation Test ===" -ForegroundColor Cyan
try {
  $testPrefix = "192.168.100.0/24"
  $testName = "TestNAT"

  # Test with IPv4-only mode
  Write-Host "Testing NAT creation with IPv4-only mode..." -ForegroundColor Yellow
  New-WinRouterNatRule -Name $testName -InternalIPInterfaceAddressPrefix $testPrefix -IPv4Only

  Write-Host "NAT rule created successfully in IPv4-only mode." -ForegroundColor Green
}
catch {
  Write-Host "Error creating NAT rule: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Test NAT rule removal
Write-Host "`n=== NAT Rule Removal Test ===" -ForegroundColor Cyan
try {
  $testName = "TestNAT"
  $existing = Get-NetNat | Where-Object { $_.Name -eq $testName }
  if ($existing) {
    Write-Host "Removing test NAT rule..." -ForegroundColor Yellow
    Remove-WinRouterNatRule -NatRule $existing
    Write-Host "Test NAT rule removed successfully." -ForegroundColor Green
  }
  else {
    Write-Host "No test NAT rule found to remove." -ForegroundColor Yellow
  }
}
catch {
  Write-Host "Error removing NAT rule: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test system information
Write-Host "`n=== System Information Test ===" -ForegroundColor Cyan
Write-Host "Windows version: $(Get-ComputerInfo | Select-Object WindowsProductName)"
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Administrator privileges: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"

# Test 5: Test network interfaces
Write-Host "`n=== Network Interface Test ===" -ForegroundColor Cyan
$interfaces = Get-WinRouterInterfaces
if ($interfaces.Count -gt 0) {
  Write-Host "Network interfaces found:" -ForegroundColor Green
  $interfaces | Format-Table Name, IP, Status -AutoSize
}
else {
  Write-Host "No network interfaces found." -ForegroundColor Red
}

Write-Host "`n=== Testing Complete ===" -ForegroundColor Cyan
Write-Host "If all tests passed, the NAT functionality should be working correctly." -ForegroundColor Green