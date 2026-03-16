# WinRouter - NAT Rule Removal
# Metodo Validado WinNAT (2026-03-15)
#
# Responsabilidade: Remover regras NAT usando abordagem "Clean Slate"
# - Remove TODAS as regras NAT (sem filtro por prefixo/nome)
# - Garante WinNAT ativo antes de operar
# - Unico caso especial: StopPending -> throw com msg de reboot

if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\core\Logger.ps1"
}

function Remove-WinRouterNatRule {
    <#
    .SYNOPSIS
    Remove regras NAT usando metodo "Clean Slate" (remocao total).

    .DESCRIPTION
    Implementa o metodo validado para remocao de regras NAT no Windows:
    1. Garante que servico WinNAT esta ativo
    2. Remove TODAS as regras NAT existentes (sem filtro)
    3. Aguarda 2 segundos para propagacao

    .PARAMETER Description
    Descricao opcional da operacao (ex: nome da regra sendo removida)

    .EXAMPLE
    Remove-WinRouterNatRule -Description "Limpeza manual"

    .NOTES
    Metodo validado em producao - 2026-03-15
    Baseado em: Configurar-NAT-Rede50.ps1, nat-rede50-desktop.ps1
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Description = "All Rules"
    )

    Write-Log "Iniciando remocao de regras NAT (Clean Slate: $Description)..." "INFO"

    # ========================================================================
    # PASSO 1: Garantir que servico WinNAT esta ativo
    # ========================================================================
    try {
        Set-Service -Name "WinNAT" -StartupType Automatic -ErrorAction Stop
        Start-Service -Name "WinNAT" -ErrorAction SilentlyContinue
        Write-Log "Servico WinNAT ativo." "INFO"
    }
    catch {
        Write-Log "Aviso ao iniciar WinNAT: $_" "WARN"
        # Nao interrompe - tenta remover mesmo assim
    }

    # ========================================================================
    # PASSO 2: Remover TODAS as regras NAT (Clean Slate - sem filtro)
    # ========================================================================
    try {
        $existing = Get-NetNat -ErrorAction SilentlyContinue
        
        if ($existing) {
            $count = @($existing).Count
            Write-Log "Removendo $count regra(s) NAT existente(s)..." "INFO"
            
            $existing | Remove-NetNat -Confirm:$false -ErrorAction Stop
            
            Start-Sleep -Seconds 2
            Write-Log "Regras NAT removidas com sucesso." "SUCCESS"
        }
        else {
            Write-Log "Nenhuma regra NAT para remover." "INFO"
        }
    }
    catch {
        $errMsg = $_.Exception.Message

        # UNICO CASO ESPECIAL: Driver WinNAT travado (StopPending)
        if ($errMsg -match 'StopPending|nao ha suporte|not supported') {
            Write-Log "CRITICO: WinNAT em estado invalido (StopPending)." "ERROR"
            Write-Log "Driver kernel travado - reboot necessario." "ERROR"
            throw "WinNAT travado. Execute: Restart-Computer. Erro: $errMsg"
        }

        # Outros erros: loga mas nao interrompe (idempotencia)
        Write-Log "Aviso na remocao NAT: $_" "WARN"
    }

    Write-Log "Finalizada remocao de regras NAT." "INFO"
}
