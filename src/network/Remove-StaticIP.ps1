function Remove-WinRouterStaticIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$InterfaceIndex
    )

    Write-Host "Reverting interface index $InterfaceIndex to Dynamic IP (DHCP)..." -ForegroundColor Cyan

    try {
        # Enable DHCP for IPv4
        Set-NetIPInterface -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop
        
        # Reset DNS addresses to be obtained automatically
        Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue

        Write-Host "Successfully enabled DHCP on interface index $InterfaceIndex." -ForegroundColor Green
    } catch {
        Write-Error "Failed to enable DHCP: $($_.Exception.Message)"
        throw
    }
}
