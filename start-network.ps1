#Requires -Version 7.0
#Requires -Modules Microsoft.PowerShell.Management

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Inicializa Core: Logger e Elevação ---
. "$PSScriptRoot\src\core\Logger.ps1"
. "$PSScriptRoot\src\core\Elevation.ps1"

Write-Log "Iniciando WinRouter..." -Level 'INFO'
Invoke-SelfElevation -ScriptPath $PSCommandPath

Write-Log "Rodando como Administrador." -Level 'SUCCESS'

# --- Carrega todos os módulos ---
Import-Module "$PSScriptRoot\src\WinRouter.psm1" -Force

# --- Menu principal ---
# ...
