function Set-WinRouterStaticIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$InterfaceIndex,

        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [int]$PrefixLength = 24
    )

    Write-Log "Starting static IP configuration process..." "INFO"
    Write-Log "Configuring static IP $IPAddress/$PrefixLength on interface index $InterfaceIndex" "INFO"

    # Remove existing IPv4 addresses to avoid conflicts or multiple IPs on the same interface
    # SilentlyContinue because there might be no IPs to remove
    Write-Log "Removing existing IPv4 addresses from interface index $InterfaceIndex" "INFO"
    Remove-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

    # Add the new static IP address
    Write-Log "Adding new static IP address: $IPAddress" "INFO"
    try {
        New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop | Out-Null
        Write-Log "Static IP configuration successful: $IPAddress on interface index $InterfaceIndex" "SUCCESS"
        Write-Host "Successfully configured $IPAddress on interface index $InterfaceIndex." -ForegroundColor Green
    }
    catch {
        Write-Log "ERROR: Failed to set static IP: $($_.Exception.Message)" "ERROR"
        Write-Error "Failed to set static IP: $($_.Exception.Message)"
        throw
    }
}
