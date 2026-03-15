function Set-WinRouterStaticIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$InterfaceIndex,

        [Parameter(Mandatory=$true)]
        [string]$IPAddress,

        [int]$PrefixLength = 24
    )

    Write-Host "Configuring static IP $IPAddress/$PrefixLength on interface index $InterfaceIndex..." -ForegroundColor Cyan

    # Remove existing IPv4 addresses to avoid conflicts or multiple IPs on the same interface
    # SilentlyContinue because there might be no IPs to remove
    Remove-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

    # Add the new static IP address
    try {
        New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop | Out-Null
        Write-Host "Successfully configured $IPAddress on interface index $InterfaceIndex." -ForegroundColor Green
    } catch {
        Write-Error "Failed to set static IP: $($_.Exception.Message)"
        throw
    }
}
