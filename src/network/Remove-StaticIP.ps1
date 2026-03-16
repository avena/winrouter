function Remove-WinRouterStaticIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$InterfaceIndex
    )

    Write-Log "Starting static IP removal process..." "INFO"
    Write-Log "Reverting interface index $InterfaceIndex to Dynamic IP (DHCP)" "INFO"

    try {
        # Enable DHCP for IPv4
        Write-Log "Enabling DHCP for IPv4 on interface index $InterfaceIndex" "INFO"
        Set-NetIPInterface -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop
        
        # Reset DNS addresses to be obtained automatically
        Write-Log "Resetting DNS server addresses to automatic on interface index $InterfaceIndex" "INFO"
        Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue

        Write-Log "DHCP configuration successful on interface index $InterfaceIndex" "SUCCESS"
        Write-Host "Successfully enabled DHCP on interface index $InterfaceIndex." -ForegroundColor Green
    }
    catch {
        Write-Log "ERROR: Failed to enable DHCP: $($_.Exception.Message)" "ERROR"
        Write-Error "Failed to enable DHCP: $($_.Exception.Message)"
        throw
    }
}
