function Get-WinRouterNatRules {
    [CmdletBinding()]
    param()
    
    # Retrieves all NetNat rules (active and inactive)
    return @(Get-NetNat -ErrorAction SilentlyContinue)
}

function Get-WinRouterNatRulesActive {
    [CmdletBinding()]
    param()
    
    # Retrieves only active NetNat rules
    return @(Get-NetNat -ErrorAction SilentlyContinue | Where-Object { $_.Active -eq $true })
}
