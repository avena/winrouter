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

function Get-WinRouterNatStatusDetailed {
    <#
    .SYNOPSIS
    Lista regras NAT com indicador se e propria ([WinRouter]) ou externa ([EXTERNA]).

    .DESCRIPTION
    Usa Test-IsOwnedNatRule para verificar se cada regra segue a convencao
    WR-NAT-{base}. Regras que nao seguem este padrao sao marcadas como externas.

    .EXAMPLE
    Get-WinRouterNatStatusDetailed

    .OUTPUTS
    Lista formatada de regras NAT com indicadores de propriedade
    #>

    param()

    $rules = @(Get-NetNat -ErrorAction SilentlyContinue)

    if ($rules.Count -eq 0) {
        Write-Host "  Nenhuma regra NAT encontrada." -ForegroundColor Gray
        return
    }

    foreach ($rule in $rules) {
        $isOwned = Test-IsOwnedNatRule -NatName $rule.Name
        $ownerLabel = if ($isOwned) { '[WinRouter]' } else { '[EXTERNA]' }
        $ownerColor = if ($isOwned) { 'Green' } else { 'Yellow' }
        $activeLabel = if ($rule.Active) { '[ATIVA]' } else { '[INATIVA]' }
        $activeColor = if ($rule.Active) { 'Green' } else { 'Gray' }

        $namePadding = $rule.Name.PadRight(25)
        $prefixPadding = $rule.InternalIPInterfaceAddressPrefix.PadRight(20)

        Write-Host "  $namePadding $prefixPadding " -NoNewline
        Write-Host "$ownerLabel " -ForegroundColor $ownerColor -NoNewline
        Write-Host "$activeLabel" -ForegroundColor $activeColor
    }
}
