#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# Test script to verify NAT rule creation fix

Write-Host "Testing NAT Rule Creation Fix" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Load the NAT module
. "$PSScriptRoot\src\nat\New-NatRule.ps1"

# Test parameters
$testNatName = "NAT-Test-60"
$testPrefix = "192.168.60.0/24"

Write-Host "Test 1: Creating NAT rule with IPv4-only mode" -ForegroundColor Yellow
Write-Host "NAT Name: $testNatName" -ForegroundColor Gray
Write-Host "Prefix: $testPrefix" -ForegroundColor Gray
Write-Host ""

try {
  # Test IPv4-only mode
  New-WinRouterNatRule -Name $testNatName -InternalIPInterfaceAddressPrefix $testPrefix -IPv4Only
  Write-Host "✓ IPv4-only mode test completed" -ForegroundColor Green
}
catch {
  Write-Host "✗ IPv4-only mode test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test 2: Checking if NAT rule was created" -ForegroundColor Yellow

# Check if the rule exists
$createdRule = Get-NetNat -Name $testNatName -ErrorAction SilentlyContinue
if ($createdRule) {
  Write-Host "✓ NAT rule '$testNatName' was created successfully" -ForegroundColor Green
  Write-Host "  Prefix: $($createdRule.InternalIPInterfaceAddressPrefix)" -ForegroundColor Gray
  Write-Host "  Status: $($createdRule.Active)" -ForegroundColor Gray
}
else {
  Write-Host "✗ NAT rule '$testNatName' was not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test 3: Cleaning up test NAT rule" -ForegroundColor Yellow

# Clean up
if ($createdRule) {
  try {
    Remove-NetNat -Name $testNatName -Confirm:$false -ErrorAction Stop
    Write-Host "✓ Test NAT rule removed successfully" -ForegroundColor Green
  }
  catch {
    Write-Host "✗ Failed to remove test NAT rule: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  This is expected if the rule creation failed" -ForegroundColor Yellow
  }
}
else {
  Write-Host "No test rule to clean up" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Test completed. If IPv4-only mode worked, the original error should be resolved." -ForegroundColor Green
Read-Host "Press Enter to exit"