function Test-NatPrerequisites {
  <#
    .SYNOPSIS
    Diagnóstico completo antes de operações NAT.
    Verifica IPv6, WinNAT, regras existentes e outros pré-requisitos.
    #>
  param(
    [Parameter(Mandatory)]
    [string]$InterfaceAlias
  )
    
  Write-Log "=== DIAGNOSTICO PRE-NAT ===" "INFO"
    
  # 1. IPv6 global
  $dc = (Get-ItemProperty `
      -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' `
      -Name 'DisabledComponents' -ErrorAction SilentlyContinue).DisabledComponents
  Write-Log "IPv6 DisabledComponents: $(if ($null -eq $dc) { 'nao definido (padrao=habilitado)' } else { '0x{0:X}' -f $dc })" "INFO"
    
  # 2. IPv6 no adaptador
  if ($InterfaceAlias) {
    $b = Get-NetAdapterBinding -InterfaceAlias $InterfaceAlias `
      -ComponentID 'ms_tcpip6' -ErrorAction SilentlyContinue
    Write-Log "IPv6 binding em '$InterfaceAlias': $(if ($b) { $b.Enabled } else { 'nao encontrado' })" "INFO"
  }
    
  # 3. WinNAT status
  $svc = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue
  Write-Log "WinNAT: $($svc.Status) / $($svc.StartType)" "INFO"
    
  # 4. Regras NAT existentes
  $nats = @(Get-NetNat -ErrorAction SilentlyContinue)
  Write-Log "Regras NAT existentes: $($nats.Count)" "INFO"
  foreach ($n in $nats) {
    Write-Log "  - '$($n.Name)' [$($n.InternalIPInterfaceAddressPrefix)] Active=$($n.Active)" "INFO"
  }
    
  Write-Log "=== FIM DIAGNOSTICO ===" "INFO"
    
  # Retornar objeto com status resumido
  return [PSCustomObject]@{
    DisabledComponents = $dc
    AdapterBinding     = if ($b) { $b.Enabled } else { $null }
    WinNATStatus       = $svc.Status
    WinNATStartType    = $svc.StartType
    NatCount           = $nats.Count
    IsCompatible       = ($dc -ne 0xFF -and $dc -ne 0xFFFFFFFF)
  }
}