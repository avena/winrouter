#!/usr/bin/env pwsh
#Requires -RunAsAdministrator
param()

$ErrorActionPreference = 'Stop'
$LANPrefix = "192.168.50.0/24"
$LANIP = "192.168.50.1"

Write-Host "========================================`n  Configurando NAT - Rede 192.168.50.x`n========================================`n" -ForegroundColor Cyan

# 0. Verificar suporte a WinNAT
if (-not (Get-Command -Name 'Get-NetNat' -ErrorAction SilentlyContinue)) {
    Write-Error "Cmdlets de NAT (NetNat) não disponíveis. Instale RSAT ou recurso Routing Tools."
    exit 1
}

Write-Host "Suporte a NAT confirmado. Prosseguindo..." -ForegroundColor Green

# 1. Listar interfaces com numeração automática
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } | Sort-Object Status -Descending
$interfaces = for ($i = 1; $i -le $adapters.Count; $i++) {
    $adapter = $adapters[$i-1]
    $ip = (Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    [PSCustomObject]@{
        Num = $i
        Name = $adapter.Name
        MAC = $adapter.MacAddress
        IP = if ($ip) { $ip } else { "Nenhum" }
        Status = $adapter.Status
    }
}

Write-Host "Interfaces disponiveis:`n"
$interfaces | Format-Table Num, Name, MAC, IP, Status -AutoSize

# 2. Escolher WAN
$wanNum = Read-Host "`nNumero da interface WAN (internet)"
$wanAdapter = $interfaces | Where-Object { $_.Num -eq [int]$wanNum }
if (-not $wanAdapter) { Write-Error "Interface WAN inválida"; exit 1 }

# 3. Escolher LAN(s)
$lanNumsInput = Read-Host "`nNumeros das interfaces LAN (ex: '4' ou '4 5')"
$lanNums = $lanNumsInput.Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { [int]$_ }
$lanAdapters = $interfaces | Where-Object { $lanNums -contains $_.Num }
if (-not $lanAdapters) { Write-Error "Interfaces LAN inválidas"; exit 1 }

Write-Host "`n  WAN : '$($wanAdapter.Name)' (MAC: $($wanAdapter.MAC))`n  LANs: $($lanAdapters.Name -join ', ')`n" -ForegroundColor Green

# 4. Configurar WinNAT (limpar e criar)
Write-Host "  [1/6] Configurando WinNAT..." -ForegroundColor Cyan
Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -like "*$LANPrefix*" } | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue

New-NetNat -Name "NAT-Rede50-$env:COMPUTERNAME" -InternalIPInterfaceAddressPrefix $LANPrefix
Write-Host "   WinNAT iniciado" -ForegroundColor Green

# 5. Configurar IPs nas interfaces LAN
Write-Host "  [2/6] Configurando IPs nas interfaces LAN..." -ForegroundColor Cyan
foreach ($lan in $lanAdapters) {
    $lanAdapterObj = $adapters | Where-Object { $_.Name -eq $lan.Name }
    $interfaceIndex = $lanAdapterObj.InterfaceIndex
    Remove-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $LANIP -PrefixLength 24 -ErrorAction SilentlyContinue
    Write-Host "   $($lan.Name): $LANIP/24 configurado"
}

# 6. Habilitar IP Forwarding
Write-Host "  [3/6] Habilitando IP Forwarding..." -ForegroundColor Cyan
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -Value 1
Write-Host "   IPEnableRouter = 1" -ForegroundColor Green

# 7. Verificar rota padrão via WAN
Write-Host "  [4/6] Verificando rota padrao via '$($wanAdapter.Name)'..." -ForegroundColor Cyan
$wanGateway = (Get-NetRoute -InterfaceAlias $wanAdapter.Name -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
if ($wanGateway) {
    Write-Host "   Gateway detectado: $wanGateway" -ForegroundColor Green
} else {
    Write-Warning "   Sem rota padrão detectada na WAN. Verifique conexão."
}

# 8. Confirmar NAT ativa (CORRIGIDO: checa depois de criar)
Write-Host "  [5/6] Confirmando regras NAT..." -ForegroundColor Cyan
Start-Sleep 1  # Aguarda propagação
$natRule = Get-NetNat | Where-Object { $_.Name -like "*NAT-Rede50*" }
if ($natRule) {
    Write-Host "   Regra NAT '$($natRule.Name)' ativa para $($natRule.InternalIPInterfaceAddressPrefix)" -ForegroundColor Green
} else {
    Write-Warning "   Regra NAT não encontrada após criação!"
}

# 9. Verificação final
Write-Host "  [6/6] Verificando configuracao final...`n" -ForegroundColor Cyan

Write-Host "Rotas padrao ativas:`n" -ForegroundColor Green
Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object InterfaceAlias, NextHop, RouteMetric | Format-Table -AutoSize

Write-Host "`nRegras NAT:`n" -ForegroundColor Green
Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix | Format-Table -AutoSize

Write-Host "`nIPs da interface LAN:`n" -ForegroundColor Green
foreach ($lan in $lanAdapters) {
    Get-NetIPAddress -InterfaceAlias $lan.Name -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength
}

# Fluxo visual
Write-Host "`n========================================`n  FLUXO DOS PACOTES`n========================================`n" -ForegroundColor Magenta
Write-Host "  [WAN: $($wanAdapter.Name)]  Gateway: $wanGateway`n    |`n    v`n  [Internet]`n    ^`n    |`n  [LAN: $($lanAdapters.Name -join ', ') 192.168.50.x]`n========================================`n" -ForegroundColor Yellow

Write-Host "`n✅ CONFIGURAÇÃO CONCLUÍDA!`n" -ForegroundColor Green
Write-Host "- Cliente deve usar gateway $LANIP`n- DNS: 8.8.8.8 ou DNS do provedor`n- Teste: ping 8.8.8.8 no cliente`n" -ForegroundColor Cyan

Read-Host "`nPressione ENTER para sair"
