# PowerShell 7: Verifica se o script está sendo executado com privilégios de administrador
# Esta função usa a API Windows para consultar a identidade do processo atual
# e verificar se pertence ao grupo de Administradores do Windows.
# Retorna $true se estiver em modo administrador, $false caso contrário.
function Test-IsAdmin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  return $isAdmin
}

# PowerShell 7: Eleva automaticamente o script para executar como administrador
function Invoke-SelfElevation {
  param(
    [string]$ScriptPath = $MyInvocation.PSCommandPath
  )

  if (-not (Test-IsAdmin)) {
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
      Write-Log "Solicitando elevação de privilégios..." -Level 'WARN'
    } else {
      Write-Host "Solicitando elevação de privilégios..." -ForegroundColor Yellow
    }

    $pwsh = (Get-Process -Id $PID).Path
    $argList = @(
      '-NoLogo'
      '-NoProfile'
      '-ExecutionPolicy', 'Bypass'
      '-File', "`"$ScriptPath`""
    )

    try {
      Start-Process -FilePath $pwsh -Verb RunAs -ArgumentList $argList
      exit
    } catch {
      if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Falha ao solicitar elevação: $($_.Exception.Message)" -Level 'ERROR'
      } else {
        Write-Error "Falha ao solicitar elevação: $($_.Exception.Message)"
      }
      throw
    }
  }
}
