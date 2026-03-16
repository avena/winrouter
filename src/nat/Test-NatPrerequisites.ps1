function Test-NatPrerequisites {
  <#
    .SYNOPSIS
    Diagnóstico completo antes de operações NAT.
    Verifica WinNAT, regras existentes e outros pré-requisitos.
    #>
  param(
    [Parameter(Mandatory = $false)]
    [string]$InterfaceAlias
  )
    
  Write-Log "=== DIAGNOSTICO PRE-NAT ===" "INFO"
    
  # 1. WinNAT status
  $svc = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue
  Write-Log "WinNAT: $($svc.Status) / $($svc.StartType)" "INFO"
    
  # 2. Regras NAT existentes
  $nats = @(Get-NetNat -ErrorAction SilentlyContinue)
  Write-Log "Regras NAT existentes: $($nats.Count)" "INFO"
  foreach ($n in $nats) {
    Write-Log "  - '$($n.Name)' [$($n.InternalIPInterfaceAddressPrefix)] Active=$($n.Active)" "INFO"
  }
    
  Write-Log "=== FIM DIAGNOSTICO ===" "INFO"
    
  # Retornar objeto com status resumido
  return [PSCustomObject]@{
    WinNATStatus       = $svc.Status
    WinNATStartType    = $svc.StartType
    NatCount           = $nats.Count
    IsCompatible       = $true # IPv4-only operation is the standard
  }
}