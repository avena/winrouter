#Requires -Version 7

# ==============================================================================
# Self-elevation: relanca como Admin se necessario
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Relancando como Administrador..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $MyInvocation.MyCommand.Path
    ) -Verb RunAs
    exit
}

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ==============================================================================
# Log setup - salva na pasta do proprio script
# ==============================================================================
$LogDir   = $PSScriptRoot
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile  = "$LogDir\config-nat-multi-$Timestamp.log"
$LogLevels = @{ 'INFO' = 'Cyan'; 'WARN' = 'Yellow'; 'ERROR' = 'Red'; 'SUCCESS' = 'Green' }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $LogLevels[$Level]
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Write-LogCmd { param([string]$Cmd); Write-Log "EXEC: $Cmd" 'INFO' }

Write-Log "INICIO NAT MANAGER + Config Multi" 'INFO'
Write-Log "Script : $($MyInvocation.MyCommand.Path)" 'INFO'
Write-Log "Log    : $LogFile" 'INFO'
Write-Log "Host   : $env:COMPUTERNAME | User: $env:USERNAME" 'INFO'

# ==============================================================================
# Verificar suporte NAT
# ==============================================================================
if (-not (Get-Command 'Get-NetNat' -ErrorAction SilentlyContinue)) {
    Write-Log "ERRO: NetNat cmdlets nao disponiveis. Instale RSAT Routing Tools." 'ERROR'
    Read-Host "Pressione ENTER para sair"
    exit 1
}
Write-Log "NetNat support: OK" 'SUCCESS'

# ==============================================================================
# TIPO 1: Analise completa - IPForwarding + NATs + Interfaces
# ==============================================================================
Write-Log "TIPO 1 - Analisando estado atual" 'INFO'

# IP Forwarding
$ipForwardVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
    -Name IPEnableRouter -ErrorAction SilentlyContinue).IPEnableRouter
$forwardStatus = if ($ipForwardVal -eq 1) { 'ATIVO' } else { 'INATIVO' }
Write-Log "IPForwarding: $forwardStatus (valor=$ipForwardVal)" 'INFO'

# Regras NAT
$nats = @(Get-NetNat -ErrorAction SilentlyContinue)
Write-Log "Regras NAT encontradas: $($nats.Count)" 'INFO'
foreach ($nat in $nats) {
    Write-Log "  NAT: $($nat.Name) -> $($nat.InternalIPInterfaceAddressPrefix)" 'INFO'
}

# Interfaces
$adapters = Get-NetAdapter |
    Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } |
    Sort-Object Status -Descending

$interfaces = for ($i = 0; $i -lt $adapters.Count; $i++) {
    $adapter = $adapters[$i]
    $ips     = @(Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex `
                    -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    $ipMain  = if ($ips.Count -gt 0) { $ips[0].IPAddress } else { 'None' }
    $allIPs  = if ($ips.Count -gt 0) { $ips.IPAddress -join ', ' } else { '' }

    # Detecta gateway privado (.1) em qualquer faixa RFC1918
    $isGateway = $ips | Where-Object {
        $_.IPAddress -match '^(10|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.1$'
    }

    # Associa NAT pela subnet do IP da interface
    $natAssociada = $nats | Where-Object {
        $prefix = ($_.InternalIPInterfaceAddressPrefix -replace '/\d+$', '') -replace '\.\d+$', ''
        $ips.IPAddress | Where-Object { $_ -like "$prefix.*" }
    }

    [PSCustomObject]@{
        Letra      = [char](65 + $i)
        Name       = $adapter.Name
        MAC        = $adapter.MacAddress
        IP         = $ipMain
        AllIPs     = $allIPs
        Status     = $adapter.Status
        GatewayNAT = if ($isGateway) { "GATEWAY: $($isGateway.IPAddress -join ',')" } else { 'Free' }
        NAT        = if ($natAssociada) { $natAssociada.Name -join ', ' } else { 'None' }
    }
}

# Tabela analise
Write-Host ''
Write-Host '=== ANALISE DE INTERFACES ===' -ForegroundColor Magenta
$interfaces | Format-Table Letra, Name, IP, GatewayNAT, NAT, Status -AutoSize -Wrap

foreach ($iface in $interfaces) {
    Write-Log "Interface $($iface.Letra): Name=[$($iface.Name)] IP=[$($iface.IP)] GW=[$($iface.GatewayNAT)] NAT=[$($iface.NAT)] Status=[$($iface.Status)]" 'INFO'
}

# Resumo executivo
$gwCount   = ($interfaces | Where-Object { $_.GatewayNAT -ne 'Free' }).Count
$freeCount = ($interfaces | Where-Object { $_.GatewayNAT -eq 'Free' }).Count

Write-Host ''
Write-Host '=== RESUMO EXECUTIVO ===' -ForegroundColor Cyan
Write-Host "  Interfaces total    : $($interfaces.Count)"
Write-Host "  Interfaces livres   : $freeCount"
Write-Host "  Gateways NAT ativos : $gwCount"
Write-Host "  Regras NAT total    : $($nats.Count)"
Write-Host "  IPForwarding        : $forwardStatus"

Write-Log "Resumo: interfaces=$($interfaces.Count) livres=$freeCount gateways=$gwCount nats=$($nats.Count) ipforward=$forwardStatus" 'INFO'

# ==============================================================================
# Menu de acao
# ==============================================================================
Write-Host ''
Write-Host '  S = Configurar nova rede NAT'  -ForegroundColor Green
Write-Host '  N = Limpar tudo (CleanAll)'    -ForegroundColor Yellow
Write-Host '  Q = Sair sem alteracoes'       -ForegroundColor Gray
$acao = Read-Host "`nEscolha"
Write-Log "Acao escolhida: $acao" 'INFO'

# ==============================================================================
# CLEAN ALL
# ==============================================================================
if ($acao -match '^[Nn]') {
    Write-Log "Iniciando limpeza total..." 'WARN'

    if ($nats.Count -gt 0) {
        $nats | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "$($nats.Count) regra(s) NAT removida(s)" 'SUCCESS'
    } else {
        Write-Log "Nenhuma regra NAT para remover" 'INFO'
    }

    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
        -Name IPEnableRouter -Value 0
    Write-Log "IPForwarding desabilitado" 'SUCCESS'

    foreach ($iface in ($interfaces | Where-Object { $_.GatewayNAT -ne 'Free' })) {
        $ifIndex = ($adapters | Where-Object Name -eq $iface.Name).InterfaceIndex
        Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -match '^(10|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.1$' } |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Gateway IP removido de: $($iface.Name)" 'SUCCESS'
    }

    Write-Log "LIMPEZA CONCLUIDA" 'SUCCESS'
    Write-Host "Log salvo em: $LogFile" -ForegroundColor Green
    Read-Host "Pressione ENTER para sair"
    exit
}

if ($acao -notmatch '^[Ss]') {
    Write-Log "Saindo sem alteracoes" 'INFO'
    exit
}

# ==============================================================================
# CONFIG NOVA
# ==============================================================================
Write-Log "Iniciando configuracao multi-redes" 'INFO'

Write-Host ''
Write-Host 'Escolha as interfaces (apenas as marcadas como Free)' -ForegroundColor Yellow
$interfaces | Format-Table Letra, Name, GatewayNAT, Status -AutoSize

# WAN
$wanLetra = (Read-Host "`nLetra da WAN (gateway/internet)").ToUpper()
$wan = $interfaces | Where-Object { $_.Letra -eq $wanLetra -and $_.GatewayNAT -eq 'Free' }
if (-not $wan) {
    Write-Log "ERRO: WAN invalida ou nao esta Free: $wanLetra" 'ERROR'
    Read-Host "Pressione ENTER para sair"
    exit 1
}
Write-Log "WAN: $($wan.Name) [$($wan.IP)]" 'INFO'

# LANs
$lanInput    = (Read-Host "`nLetras das LANs (Free only, ex: B C)").ToUpper()
$lanLetras   = $lanInput.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
$lanAdapters = $interfaces | Where-Object { $lanLetras -contains $_.Letra -and $_.GatewayNAT -eq 'Free' }
if (-not $lanAdapters) {
    Write-Log "ERRO: nenhuma LAN valida selecionada" 'ERROR'
    Read-Host "Pressione ENTER para sair"
    exit 1
}
Write-Log "LANs selecionadas: $($lanAdapters.Name -join ', ')" 'INFO'

# Redes por LAN
$lanConfigs = @{}
$base = 50
foreach ($lan in $lanAdapters) {
    $sugestao = "192.168.$base.0/24"
    $rede     = Read-Host "Rede para $($lan.Letra) - $($lan.Name) [$sugestao]"
    if (-not $rede) { $rede = $sugestao }
    $lanConfigs[$lan.Letra] = $rede
    Write-Log "LAN $($lan.Letra): rede=$rede" 'INFO'
    $base += 10
}

# Confirmacao
Write-Host ''
Write-Host "WAN : $($wan.Letra) - $($wan.Name)" -ForegroundColor Cyan
foreach ($kv in $lanConfigs.GetEnumerator()) {
    $lanName = ($interfaces | Where-Object Letra -eq $kv.Key).Name
    Write-Host "LAN $($kv.Key) : $lanName -> $($kv.Value)" -ForegroundColor Cyan
}

$confirm = Read-Host "`nConfirmar e aplicar? S/N"
if ($confirm -notmatch '^[Ss]') {
    Write-Log "Config cancelada pelo usuario" 'WARN'
    exit
}

# ==============================================================================
# APLICAR
# ==============================================================================

# 1. Remover NATs existentes
Write-Log "Removendo NATs existentes..." 'INFO'
$nats | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
Write-Log "NATs antigos removidos" 'SUCCESS'

# 2. Criar NAT por sub-rede
foreach ($kv in $lanConfigs.GetEnumerator()) {
    $natName = "NAT-$($kv.Key)-$env:COMPUTERNAME"
    Write-LogCmd "New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $($kv.Value)"
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $kv.Value -ErrorAction Stop | Out-Null
    Write-Log "NAT criado: $natName -> $($kv.Value)" 'SUCCESS'
}

# 3. IP Forwarding
Write-LogCmd "Set-ItemProperty IPEnableRouter = 1"
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
    -Name IPEnableRouter -Value 1
Write-Log "IPForwarding habilitado" 'SUCCESS'

# 4. IPs gateway .1 nas LANs
foreach ($lan in $lanAdapters) {
    $rede    = $lanConfigs[$lan.Letra]
    $ipGw    = ($rede -split '/')[0] -replace '\.0$', '.1'
    $prefix  = 24
    $ifIndex = ($adapters | Where-Object Name -eq $lan.Name).InterfaceIndex

    Write-LogCmd "Remove-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4"
    Remove-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 `
        -Confirm:$false -ErrorAction SilentlyContinue

    Write-LogCmd "New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $ipGw -PrefixLength $prefix"
    New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $ipGw -PrefixLength $prefix `
        -ErrorAction Stop | Out-Null

    Write-Log "IP configurado: $($lan.Name) = $ipGw/$prefix" 'SUCCESS'
}

# ==============================================================================
# Verificacao Final
# ==============================================================================
Write-Log "--- VERIFICACAO FINAL ---" 'INFO'

$natsAtivos = @(Get-NetNat -ErrorAction SilentlyContinue)
foreach ($n in $natsAtivos) {
    Write-Log "  NAT ativo: $($n.Name) -> $($n.InternalIPInterfaceAddressPrefix)" 'INFO'
}

Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Log "  Rota default: $($_.InterfaceAlias) -> $($_.NextHop)" 'INFO'
}

foreach ($lan in $lanAdapters) {
    $ipFinal = (Get-NetIPAddress -InterfaceAlias $lan.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    Write-Log "  LAN $($lan.Letra) IP final: $ipFinal" 'INFO'
}

Write-Log "CONFIG FINALIZADA! Reinicie o PC para garantir estabilidade." 'SUCCESS'
Write-Host ''
Write-Host "Log salvo em: $LogFile" -ForegroundColor Green
Read-Host "Pressione ENTER para sair"
