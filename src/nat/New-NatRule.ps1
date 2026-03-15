function New-WinRouterNatRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$InternalIPInterfaceAddressPrefix
    )

    Write-Host "Creating NAT rule '$Name' for prefix '$InternalIPInterfaceAddressPrefix'..." -ForegroundColor Cyan

    # Ensure duplicate NAT rules for the same prefix are removed before creation
    $existing = Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $InternalIPInterfaceAddressPrefix }
    if ($existing) {
        Write-Warning "NAT rule with same prefix already exists. Removing before re-creation..."
        $existing | Remove-NetNat -Confirm:$false
    }

    try {
        New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $InternalIPInterfaceAddressPrefix -ErrorAction Stop | Out-Null
        Write-Host "NAT rule created successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create NAT rule: $($_.Exception.Message)"
        throw
    }
}
