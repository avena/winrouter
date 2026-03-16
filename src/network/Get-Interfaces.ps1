function Get-WinRouterInterfaces {
    [CmdletBinding()]
    param()

    Write-Log "Starting interface discovery process..." "INFO"
    
    # Get existing NAT rules for context
    Write-Log "Retrieving existing NAT rules for context..." "INFO"
    $nats = @(Get-NetNat -ErrorAction SilentlyContinue)
    Write-Log "Found $($nats.Count) existing NAT rules" "INFO"

    # Get Adapters (Up or Disconnected)
    Write-Log "Retrieving network adapters..." "INFO"
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } | Sort-Object InterfaceIndex
    Write-Log "Found $($adapters.Count) network adapters" "INFO"

    $results = @()
    $letterCode = 65 # ASCII 'A'

    foreach ($adapter in $adapters) {
        Write-Log "Processing adapter: $($adapter.Name) (Index: $($adapter.InterfaceIndex))" "INFO"
        
        # Get IPv4 Addresses
        $ips = @(Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue)
        
        $ipAddress = if ($ips) { $ips[0].IPAddress } else { "No IP" }
        Write-Log "Adapter $($adapter.Name) has IP: $ipAddress" "INFO"

        # Gateway Detection logic: check for private range ending in .1
        $isGateway = $ips | Where-Object {
            $_.IPAddress -match '^(10|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.1$'
        }
        $gatewayStatus = if ($isGateway) { "GATEWAY" } else { "Free" }
        Write-Log "Gateway status for $($adapter.Name): $gatewayStatus" "INFO"

        # NAT Association logic: check if IP matches any NAT prefix
        $natAssociada = $nats | Where-Object {
            $prefix = ($_.InternalIPInterfaceAddressPrefix -replace '/\d+$', '') -replace '\.\d+$', ''
            $ips.IPAddress | Where-Object { $_ -like "$prefix.*" }
        }
        
        # Enhanced NAT Status display
        $natStatus = if ($natAssociada) { 
            "YES (" + ($natAssociada.Name -join ', ') + ")" 
        }
        else { 
            "NONE" 
        }
        Write-Log "NAT association for $($adapter.Name): $natStatus" "INFO"

        # Uppercase Status display
        $statusDisplay = $adapter.Status.ToUpper()
        Write-Log "Status for $($adapter.Name): $statusDisplay" "INFO"

        $obj = [PSCustomObject]@{
            Selection      = [char]$letterCode
            Name           = $adapter.Name
            InterfaceIndex = $adapter.InterfaceIndex
            MAC            = $adapter.MacAddress
            IP             = $ipAddress
            Status         = $statusDisplay
            GatewayStatus  = $gatewayStatus
            NAT            = $natStatus
        }
        
        $results += $obj
        Write-Log "Added interface $($adapter.Name) to results with selection letter: $([char]$letterCode)" "INFO"
        $letterCode++
    }
    
    Write-Log "Interface discovery complete. Processed $($results.Count) interfaces" "SUCCESS"
    return $results
}
