function New-WinRouterNatRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$InternalIPInterfaceAddressPrefix,

        [Parameter()]
        [switch]$IPv4Only
    )

    Write-Host "Creating NAT rule '$Name' for prefix '$InternalIPInterfaceAddressPrefix'..." -ForegroundColor Cyan

    # Check if IPv6 is supported
    $ipv6Supported = $false
    try {
        $ipv6Test = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue
        if ($ipv6Test) { $ipv6Supported = $true }
    }
    catch {
        Write-Log "IPv6 support check failed: $($_.Exception.Message)" "WARN"
    }

    # If IPv4-only mode is requested or IPv6 is not supported, use IPv4-only approach
    if ($IPv4Only -or -not $ipv6Supported) {
        Write-Log "Using IPv4-only mode for NAT creation" "INFO"

        # Ensure duplicate NAT rules for the same prefix are removed before creation
        $existing = Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $InternalIPInterfaceAddressPrefix }
        if ($existing) {
            Write-Warning "NAT rule with same prefix already exists. Removing before re-creation..."
            try {
                $existing | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Failed to remove existing NAT rule: $($_.Exception.Message)" "WARN"
                Write-Host "Could not remove existing NAT rule. Attempting to create new rule anyway..." -ForegroundColor Yellow
            }
        }

        try {
            # Create NAT rule with IPv4-only parameters
            New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $InternalIPInterfaceAddressPrefix -ErrorAction Stop | Out-Null
            Write-Host "NAT rule created successfully in IPv4-only mode." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to create NAT rule in IPv4-only mode: $($_.Exception.Message)"
            if ($ipv6Supported) {
                Write-Host "IPv6 is supported on this system. Consider using IPv6-compatible NAT rules." -ForegroundColor Yellow
            }
            else {
                Write-Host "IPv6 is not supported on this system. Using IPv4-only NAT rules." -ForegroundColor Yellow
            }
            throw
        }
    }
    else {
        # Standard NAT creation (IPv6 compatible)
        try {
            # Ensure duplicate NAT rules for the same prefix are removed before creation
            $existing = Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $InternalIPInterfaceAddressPrefix }
            if ($existing) {
                Write-Warning "NAT rule with same prefix already exists. Removing before re-creation..."
                $existing | Remove-NetNat -Confirm:$false
            }

            New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $InternalIPInterfaceAddressPrefix -ErrorAction Stop | Out-Null
            Write-Host "NAT rule created successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to create NAT rule: $($_.Exception.Message)"
            if (-not $ipv6Supported) {
                Write-Host "IPv6 is not supported on this system. Consider using IPv4-only mode." -ForegroundColor Yellow
            }
            throw
        }
    }
}

# System Information:
# - Windows: Windows 1 with PowerShell
# - Focus: IPv4-only configuration (no IPv6 support)
# - Privileges: Running with administrator privileges
# - Issues: NAT rule creation/removal failures due to IPv6 compatibility issues
#
# Troubleshooting Guidelines:
# 1. IPv6 Support Error: "IPV6 sem suporte" occurs during NAT creation
# 2. Remove-NetNat Operation Error: "Não há suporte à operação solicitada" during NAT removal
# 3. Root Cause: IPv6 compatibility issues in Windows NAT implementation
# 4. Solution: Implement IPv4-only mode with enhanced error handling
#
# For more information, see:
# - plans/plan.md: Detailed implementation plan
# - docs/TROUBLESHOOTING.md: Comprehensive troubleshooting guide