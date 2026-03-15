function Get-WinRouterInterfaces {
    [CmdletBinding()]
    param()

    # Get existing NAT rules for context
    $nats = @(Get-NetNat -ErrorAction SilentlyContinue)

    # Get Adapters (Up or Disconnected)
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } | Sort-Object InterfaceIndex

    $results = @()
    $letterCode = 65 # ASCII 'A'

    foreach ($adapter in $adapters) {
        # Get IPv4 Addresses
        $ips = @(Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue)
        
        $ipAddress = if ($ips) { $ips[0].IPAddress } else { "No IP" }

        # Gateway Detection logic: check for private range ending in .1
        $isGateway = $ips | Where-Object {
            $_.IPAddress -match '^(10|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.1$'
        }
        $gatewayStatus = if ($isGateway) { "GATEWAY" } else { "Free" }

        # NAT Association logic: check if IP matches any NAT prefix
        $natAssociada = $nats | Where-Object {
            $prefix = ($_.InternalIPInterfaceAddressPrefix -replace '/\d+$', '') -replace '\.\d+$', ''
            $ips.IPAddress | Where-Object { $_ -like "$prefix.*" }
        }
        
        # Enhanced NAT Status display
        $natStatus = if ($natAssociada) { 
            "YES (" + ($natAssociada.Name -join ', ') + ")" 
        } else { 
            "NONE" 
        }

        # Uppercase Status display
        $statusDisplay = $adapter.Status.ToUpper()

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
        $letterCode++
    }
    
    return $results
}
