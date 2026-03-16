#==============================================================================
# Script: Configurar-NAT-Rede60.ps1
# Descricao: Configura NAT no Windows 11 Pro para faixa 192.168.60.x
# Requisito: Executar como ADMINISTRADOR
#==============================================================================

# Verifica se esta executando como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole( `
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRO: Execute este script como ADMINISTRADOR!"
    Write-Host "Clique com botao direito no PowerShell > Executar como Administrador"
    Start-Sleep -Seconds 3
    exit 1
}

Write-Host "========================================"
Write-Host "  Configurando NAT - Rede 192.168.60.x  "
Write-Host "========================================"
Write-Host ""

#------------------------------------------------------------------------------
# 1. Configurar Servico WinNAT
#------------------------------------------------------------------------------
Write-Host "[1/5] Configurando servico WinNAT..."

try {
    Set-Service -Name "WinNAT" -StartupType Automatic -ErrorAction Stop
    Start-Service -Name "WinNAT" -ErrorAction Stop
    Write-Host "   Servico WinNAT configurado e iniciado"
} catch {
    Write-Host "   Aviso: Nao foi possivel configurar WinNAT ($_)"
}

#------------------------------------------------------------------------------
# 2. Configurar IP Estatico na Ethernet
#------------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Configurando IP na interface Ethernet..."

$InterfaceAlias = "Ethernet"  # ALTERE SE SUA PLACA TIVER OUTRO NOME
$IPAddress = "192.168.60.1"
$PrefixLength = 24

try {
    # Remove IP existente se houver conflito
    $existingIP = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -ErrorAction SilentlyContinue
    if ($existingIP) {
        Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "   IP existente removido"
    }
    
    # Cria novo IP
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop
    Write-Host "   IP $IPAddress configurado em $InterfaceAlias"
} catch {
    Write-Host "   Aviso: IP pode ja estar configurado ($_)"
}

#------------------------------------------------------------------------------
# 3. Configurar Registro (IP Enable Router)
#------------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/5] Habilitando encaminhamento de IP no registro..."

try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
        -Name "IPEnableRouter" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "   Registro IPEnableRouter = 1"
} catch {
    Write-Host "   Erro ao configurar registro: $_"
}

#------------------------------------------------------------------------------
# 4. Configurar Regra NetNat
#------------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/5] Configurando regra NAT..."

try {
    # Remove regras NAT existentes
    $existingNat = Get-NetNat -ErrorAction SilentlyContinue
    if ($existingNat) {
        $existingNat | Remove-NetNat -Confirm:$false
        Write-Host "   Regras NAT antigas removidas"
    }
    
    # Cria nova regra NAT
    New-NetNat -Name "Rede60" -InternalIPInterfaceAddressPrefix "192.168.60.0/24" -ErrorAction Stop
    Write-Host "   Regra NAT 'Rede60' criada para 192.168.60.0/24"
} catch {
    Write-Host "   Erro ao criar regra NAT: $_"
}

#------------------------------------------------------------------------------
# 5. Verificacao Final
#------------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/5] Verificando configuracao..."
Write-Host ""

Write-Host "Servico WinNAT:"
Get-Service -Name "WinNAT" | Select-Object Name, Status, StartType | Format-Table

Write-Host "Interface de Rede:"
Get-NetIPAddress -InterfaceAlias $InterfaceAlias | Where-Object {$_.IPAddress -like "192.168.60.*"} | `
    Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table

Write-Host "Regras NetNat:"
Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix | Format-Table

#------------------------------------------------------------------------------
# Resumo e Proximos Passos
#------------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================"
Write-Host "  CONFIGURACAO CONCLUIDA!               "
Write-Host "========================================"
Write-Host ""
Write-Host "PROXIMOS PASSOS:"
Write-Host "   1. Reinicie o computador (Recomendado)"
Write-Host "   2. Configure seu servidor DHCP com:"
Write-Host "      - Gateway: 192.168.60.1"
Write-Host "      - DNS: 192.168.60.1 ou 8.8.8.8"
Write-Host "      - Faixa: 192.168.60.10 a 192.168.60.200"
Write-Host "   3. Desative o ICS na placa Wi-Fi"
Write-Host "      (Propriedades > Compartilhamento > Desmarcar)"
Write-Host ""
Write-Host "PARA TESTAR:"
Write-Host "   - Conecte um dispositivo na rede Ethernet"
Write-Host "   - Verifique se recebeu IP 192.168.60.x"
Write-Host "   - Teste: ping 8.8.8.8"
Write-Host ""
Write-Host "SE NAO FUNCIONAR:"
Write-Host "   - Execute: Set-NetFirewallProfile -Profile Public,Private -Enabled False"
Write-Host "   - Verifique: Get-NetNat"
Write-Host ""

Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")