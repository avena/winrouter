# PowerShell 7: Verifica se o script está sendo executado com privilégios de administrador
# Esta função usa a API Windows para consultar a identidade do processo atual
# e verificar se pertence ao grupo de Administradores do Windows.
# Retorna $true se estiver em modo administrador, $false caso contrário.
function Test-IsAdmin {
  # Cria um objeto WindowsPrincipal baseado na identidade do processo atual
  # IsInRole verifica se a identidade possui o papel de Administrador do Windows
  ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# PowerShell 7: Eleva automaticamente o script para executar como administrador
# Se o script não estiver sendo executado com privilégios de administrador,
# esta função reinicia o script em uma nova sessão do PowerShell 7 com privilégios elevados.
# Após a elevação, o processo original é encerrado.
function Invoke-SelfElevation {
  param(
    # Caminho do script que será reexecutado com privilégios elevados
    # Por padrão, usa o caminho do script que chamou esta função
    [string]$ScriptPath = $MyInvocation.PSCommandPath
  )

  # Verifica se o script já está em modo administrador
  if (-not (Test-IsAdmin)) {
    # PS7: usa 'pwsh' — nunca 'powershell.exe'
    # Obtém o caminho exato do executável pwsh que está executando este script
    $pwsh = (Get-Process -Id $PID).Path

    # Lista de argumentos para a nova sessão do PowerShell 7
    $argList = @(
      '-NoLogo'          # Não exibe o logotipo do PowerShell
      '-NoProfile'       # Não carrega o perfil do usuário
      '-ExecutionPolicy', 'Bypass'  # Permite a execução do script sem restrições
      '-File', "`"$ScriptPath`""   # Arquivo a ser executado na nova sessão
    )

    # Inicia uma nova sessão do PowerShell 7 com privilégios de administrador
    Start-Process -FilePath $pwsh -Verb RunAs -ArgumentList $argList
    
    # Encerra o processo original após iniciar a sessão elevada
    exit
  }
}
