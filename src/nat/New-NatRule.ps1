function New-WinRouterNatRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$InternalIPInterfaceAddressPrefix
    )

    Write-Log "Configuring NAT '$Name' for '$InternalIPInterfaceAddressPrefix'..." "INFO"

    # PASSO 1: Garantir que o servico WinNAT esta ativo
    try {
        Set-Service -Name "WinNAT" -StartupType Automatic -ErrorAction Stop
        Start-Service -Name "WinNAT" -ErrorAction SilentlyContinue
        Write-Log "WinNAT service active." "INFO"
    }
    catch {
        Write-Log "Warning starting WinNAT: $_" "WARN"
    }

    # PASSO 2: Remover TODAS as regras NAT existentes (sem filtro)
    # WinNAT on Windows 10/11 supports only one NAT instance reliably.
    try {
        $existing = Get-NetNat -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Removing $(@($existing).Count) existing NAT rule(s) (Clean Slate strategy)..." "INFO"
            $existing | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Write-Log "Existing NAT rules removed." "INFO"
        }
    }
    catch {
        Write-Log "Warning removing existing NAT rules: $_" "WARN"
        # Continue anyway, let New-NetNat fail if it must
    }

    # PASSO 3: Criar regra NAT
    try {
        New-NetNat -Name $Name `
            -InternalIPInterfaceAddressPrefix $InternalIPInterfaceAddressPrefix `
            -ErrorAction Stop | Out-Null

        Write-Log "NAT rule '$Name' created successfully." "SUCCESS"
        return $true
    }
    catch {
        $errMsg = $_.Exception.Message

        # Critical Driver State check
        if ($errMsg -match 'StopPending|nao ha suporte|not supported') {
            Write-Log "CRITICAL: WinNAT Driver stuck or unsupported state. Reboot required." "ERROR"
            throw "WinNAT in invalid state (Driver stuck). Please REBOOT the system. Original error: $errMsg"
        }

        Write-Log "Failed to create NAT rule: $errMsg" "ERROR"
        throw "Failed to create NAT rule '$Name': $errMsg"
    }
}