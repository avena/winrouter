function New-WinRouterNatRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$InternalIPInterfaceAddressPrefix
    )

    Write-Log "Criando NAT IPv4-only '$Name' para '$InternalIPInterfaceAddressPrefix'..." "INFO"

    # PASSO A: Remover regra existente
    $existing = Get-NetNat -ErrorAction SilentlyContinue | 
    Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $InternalIPInterfaceAddressPrefix }
    
    if ($existing) {
        Write-Log "Regra existente encontrada: '$($existing.Name)' Active=$($existing.Active)" "WARN"
        $removeResult = Remove-WinRouterNatRule -NatRule $existing
        
        # GATE: Verificar SuccessLevel antes de criar nova regra
        if ($removeResult.SuccessLevel -ne 'FULL') {
            Write-Log "Remocao retornou '$($removeResult.SuccessLevel)'." "WARN"
            Write-Log "Regra fantasma ainda existe. New-NetNat vai falhar." "WARN"
            Write-Log "ACAO: Reinicie o PC e execute novamente." "WARN"
            throw "Falha ao remover regra existente '$Name'. SuccessLevel=$($removeResult.SuccessLevel). Reboot necessario."
        }
        Write-Log "Remocao confirmada (FULL). Prosseguindo para criacao." "INFO"
        Start-Sleep -Seconds 2
    }

    # PASSO B: Tentar criar regra IPv4-only
    $created = $false
    $maxRetries = 3
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        Write-Log "Tentativa $attempt/$maxRetries de criar NAT IPv4-only '$Name'..." "INFO"
        
        try {
            New-NetNat -Name $Name `
                -InternalIPInterfaceAddressPrefix $InternalIPInterfaceAddressPrefix `
                -ErrorAction Stop | Out-Null
            Write-Log "NAT IPv4-only '$Name' criado com sucesso." "SUCCESS"
            $created = $true
            break
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log "Tentativa $attempt falhou: $errMsg" "WARN"
            
            # Classificar a causa real antes de reagir
            $isWinnatDead = $errMsg -match 'não há suporte|not supported|StopPending'
            $isAlreadyExists = $errMsg -match 'already exists|já existe'
            $isIPv6Issue = $errMsg -match 'IPv6' -and -not $isWinnatDead

            if ($isWinnatDead) {
                Write-Log "CAUSA REAL: winnat em StopPending — provider CIM indisponivel." "ERROR"
                Write-Log "Nao e problema de IPv6. Reboot necessario para liberar driver." "ERROR"
                throw "winnat driver travado (StopPending). Reboot necessario antes de criar NAT."
            }
            elseif ($isAlreadyExists) {
                Write-Log "Regra '$Name' ainda existe (remocao incompleta)." "ERROR"
                throw "Regra '$Name' nao foi removida. SuccessLevel deve ser FULL antes de criar."
            }
            elseif ($isIPv6Issue) {
                Write-Log "Erro real de IPv6: $errMsg" "ERROR"
                throw "Problema de IPv6: $errMsg"
            }
            else {
                Write-Log "Erro desconhecido: $errMsg" "ERROR"
                throw $errMsg
            }
            
            if ($attempt -lt $maxRetries) {
                Start-Sleep -Seconds 3
            }
        }
    }

    if (-not $created) {
        Write-Log "FALHA ao criar NAT IPv4-only '$Name' apos $maxRetries tentativas." "ERROR"
        Write-Log "Solução recomendada: Reboot o sistema e tente novamente." "WARN"
        throw "Falha ao criar regra NAT IPv4-only '$Name'. Reboot o sistema e tente novamente."
    }
    
    return $created
}

# System Information:
# - Windows: Windows 1 with PowerShell
# - Focus: IPv4-only configuration (no IPv6 support)
# - Privileges: Running with administrator privileges
# - Issues: NAT rule creation/removal failures due to IPv6 compatibility issues
#
# Troubleshooting Guidelines:
# 1. IPv6 Support Error: "IPV6 sem suporte" occurs during NAT creation
# 2. Remove-NetNat Operation Error: "Não há suporte à operação solicitada" during NAT removal
# 3. Root Cause: IPv6 compatibility issues in Windows NAT implementation
# 4. Solution: Implement IPv4-only mode with enhanced error handling
#
# For more information, see:
# - plans/plan.md: Detailed implementation plan
# - docs/TROUBLESHOOTING.md: Comprehensive troubleshooting guide