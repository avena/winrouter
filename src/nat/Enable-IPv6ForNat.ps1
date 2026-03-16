function Test-IPv6Compatibility {
  <#
    .SYNOPSIS
    Verifica compatibilidade IPv6 do sistema (apenas para diagnóstico).
    #>
  param(
    [Parameter(Mandatory)]
    [string]$InterfaceAlias
  )
    
  Write-Log "Verificando compatibilidade IPv6 (diagnóstico apenas)..." "INFO"
    
  # Verifica desabilitacao global via registro
  $disabledComponents = (Get-ItemProperty `
      -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' `
      -Name 'DisabledComponents' -ErrorAction SilentlyContinue).DisabledComponents
    
  if ($disabledComponents -eq 0xFF -or $disabledComponents -eq 0xFFFFFFFF) {
    Write-Log "IPv6 globalmente desabilitado (DisabledComponents=$disabledComponents)." "WARN"
    Write-Log "Sistema não suporta IPv6. WinRouter usa IPv4-only." "INFO"
    return $false
  }
    
  Write-Log "IPv6 detectado no sistema." "INFO"
  return $true
}
