#Requires -Version 7.0
#Requires -Modules Microsoft.PowerShell.Management

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Elevação antes de qualquer coisa ---
. "$PSScriptRoot\src\core\Elevation.ps1"
Invoke-SelfElevation -ScriptPath $PSCommandPath

# --- Carrega todos os módulos ---
Import-Module "$PSScriptRoot\src\WinRouter.psm1" -Force

# --- Menu principal ---
# ...
