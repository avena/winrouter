# Logger.ps1 - Funções de log centralizadas para WinRouter

# Caminho padrão para o arquivo de log se não for definido externamente
# O diretório logs/ fica no root do projeto
if (-not $Global:LogFile) {
    $LogDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "logs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Global:LogFile = Join-Path $LogDir "winrouter-$Timestamp.log"
}

# Níveis de log e suas cores correspondentes
$Global:LogLevels = @{
    'INFO'    = 'Cyan'
    'WARN'    = 'Yellow'
    'ERROR'   = 'Red'
    'SUCCESS' = 'Green'
    'DEBUG'   = 'Gray'
}

# Função principal de log
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Escreve no console com a cor correspondente
    $Color = $Global:LogLevels[$Level]
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Tenta escrever no arquivo de log
    try {
        Add-Content -Path $Global:LogFile -Value $LogEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Se falhar ao escrever no log (ex: permissão), pelo menos o console mostrou
    }
}

# Atalho para logar comandos sendo executados
function Write-LogCmd {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cmd
    )
    
    Write-Log -Message "EXEC: $Cmd" -Level 'INFO'
}

# Exporta as funções
Export-ModuleMember -Function Write-Log, Write-LogCmd
