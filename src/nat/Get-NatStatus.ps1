function Get-WinRouterNatRules {
    [CmdletBinding()]
    param()
    
    # Retrieves all NetNat rules (active and inactive)
    return @(Get-NetNat -ErrorAction SilentlyContinue)
}
