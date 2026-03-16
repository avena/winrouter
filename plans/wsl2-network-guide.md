# WSL 2 — Rede, Interfaces e NAT Port Forward via PowerShell 7 (Windows 11)

> **Contexto para agentes de desenvolvimento**
> Este documento descreve como inspecionar e configurar a rede do WSL 2 inteiramente a partir do host Windows 11,
> usando **PowerShell 7 (pwsh)**. Serve como referência de orientação para automação, scripts e decisões de arquitetura.

---

## 1. Modelo de Rede do WSL 2

O WSL 2 roda em uma **VM leve Hyper-V**. A conectividade entre host e guest funciona assim:

```
[Windows 11 Host]
        │
        ├── Adaptador virtual: vEthernet (WSL)   ← interface no host
        │       IP ex.: 172.25.48.1/20
        │
        └── [VM WSL 2 (Linux)]
                └── eth0  IP ex.: 172.25.48.2/20
                        └── default gateway → 172.25.48.1 (host)
```

- O host faz **NAT** para o tráfego de saída da VM.
- Por padrão, serviços rodando no Linux **não são acessíveis** diretamente de outras máquinas na rede local — precisam de **port forwarding**.
- O IP da VM **muda a cada reinicialização** do WSL (subnet dinâmica).

### Referências oficiais
- [WSL Networking - Microsoft Docs](https://learn.microsoft.com/en-us/windows/wsl/networking)
- [WSL 2 Architecture](https://learn.microsoft.com/en-us/windows/wsl/compare-versions#whats-new-in-wsl-2)

---

## 2. Interfaces de Rede — Inspecionando via PowerShell 7

### 2.1 Listar todas as interfaces do host (incluindo a do WSL)

```powershell
# Lista adaptadores com IP, status e descrição
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } |
  Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed |
  Format-Table -AutoSize

# Focar no adaptador WSL
Get-NetAdapter -Name "*WSL*"
```

### 2.2 Endereços IP dos adaptadores

```powershell
# Todos os endereços IPv4 ativos
Get-NetIPAddress -AddressFamily IPv4 |
  Select-Object InterfaceAlias, IPAddress, PrefixLength |
  Format-Table -AutoSize

# Apenas o endereço da interface WSL no host
Get-NetIPAddress -InterfaceAlias "vEthernet (WSL)" -AddressFamily IPv4 |
  Select-Object IPAddress, PrefixLength
```

### 2.3 Obter o IP atual da VM WSL (a partir do host)

```powershell
# Executa `ip addr` dentro do WSL e extrai o IP de eth0
$wslIp = wsl -- ip -4 addr show eth0 |
  Select-String -Pattern '(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Value } |
  Select-Object -First 1

Write-Host "IP da VM WSL 2: $wslIp"
```

> **Para agentes:** use `$wslIp` como variável dinâmica em scripts — nunca hardcode o IP.

---

## 3. Configuração de Rede — Tabelas de Roteamento e DNS

### 3.1 Rotas do host

```powershell
# Tabela de roteamento IPv4 completa
Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric |
  Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric |
  Format-Table -AutoSize

# Rota específica pela sub-rede WSL
Get-NetRoute -AddressFamily IPv4 |
  Where-Object { $_.InterfaceAlias -like "*WSL*" }
```

### 3.2 DNS

```powershell
# Servidores DNS configurados por interface
Get-DnsClientServerAddress -AddressFamily IPv4 |
  Select-Object InterfaceAlias, ServerAddresses |
  Format-Table -AutoSize
```

### 3.3 Configuração de rede dentro do WSL (a partir do host)

```powershell
# Rota padrão dentro da VM
wsl -- ip route show

# DNS que o Linux está usando
wsl -- cat /etc/resolv.conf

# Todas as interfaces dentro da VM
wsl -- ip -4 addr show
```

---

## 4. NAT e Port Forwarding

### 4.1 Como o NAT funciona no WSL 2

O Windows usa o componente **WinNAT** (via Hyper-V) para rotear o tráfego da VM para a internet.
Port forwarding é feito via **`netsh interface portproxy`**, que registra regras no driver do kernel.

- Referência: [netsh portproxy - Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-interface-portproxy)
- Referência: [WSL Port Forwarding - Microsoft Docs](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-a-wsl-2-distribution-from-your-local-area-network-lan)

### 4.2 Criar uma regra de port forwarding

```powershell
# Redireciona porta 8080 do host → porta 8080 na VM WSL
$wslIp = (wsl -- ip -4 addr show eth0 |
  Select-String '(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Value } |
  Select-Object -First 1)

netsh interface portproxy add v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=8080 `
  connectaddress=$wslIp `
  connectport=8080

Write-Host "Port forward criado: 0.0.0.0:8080 → ${wslIp}:8080"
```

> **Requer:** PowerShell **como Administrador**.

### 4.3 Listar todas as regras de port proxy

```powershell
netsh interface portproxy show all

# Alternativa com saída estruturada para parsing em scripts
netsh interface portproxy show v4tov4
```

### 4.4 Remover uma regra específica

```powershell
netsh interface portproxy delete v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=8080
```

### 4.5 Remover todas as regras

```powershell
netsh interface portproxy reset
```

---

## 5. Firewall — Liberar a Porta no Windows Defender

O port forwarding só funciona se o **Windows Firewall** permitir a entrada na porta:

```powershell
# Criar regra de entrada para a porta 8080
New-NetFirewallRule `
  -DisplayName "WSL2 Port 8080" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 8080 `
  -Action Allow

# Listar regras relacionadas ao WSL
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*WSL*" } |
  Select-Object DisplayName, Direction, Action, Enabled
```

- Referência: [New-NetFirewallRule - Microsoft Docs](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule)

---

## 6. Script Completo — Automação de Port Forward (Re-usável)

```powershell
<#
.SYNOPSIS
    Configura port forwarding do host Windows → VM WSL 2 dinamicamente.
.DESCRIPTION
    Detecta o IP atual da VM WSL 2, cria regra de portproxy e abre o firewall.
    Ideal para ser chamado no startup do sistema ou ao reiniciar o WSL.
.PARAMETER HostPort
    Porta que ficará ouvindo no host Windows.
.PARAMETER WslPort
    Porta de destino na VM WSL (padrão: igual ao HostPort).
.EXAMPLE
    .\Set-WslPortForward.ps1 -HostPort 3000
    .\Set-WslPortForward.ps1 -HostPort 8080 -WslPort 80
#>
param(
    [Parameter(Mandatory)] [int]   $HostPort,
    [int]   $WslPort = $HostPort,
    [string]$ListenAddress = "0.0.0.0"
)

# Requer elevação
if (-not ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Execute como Administrador."
  exit 1
}

# Detectar IP da VM
$wslIp = wsl -- ip -4 addr show eth0 2>$null |
  Select-String '(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Value } |
  Select-Object -First 1

if (-not $wslIp) {
  Write-Error "Não foi possível obter o IP da VM WSL 2. O WSL está rodando?"
  exit 1
}

# Remover regra anterior (se existir) para evitar conflito
netsh interface portproxy delete v4tov4 `
  listenaddress=$ListenAddress listenport=$HostPort 2>$null

# Criar nova regra
netsh interface portproxy add v4tov4 `
  listenaddress=$ListenAddress `
  listenport=$HostPort `
  connectaddress=$wslIp `
  connectport=$WslPort

# Garantir regra de firewall
$ruleName = "WSL2-Forward-$HostPort"
Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
New-NetFirewallRule `
  -DisplayName $ruleName `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort $HostPort `
  -Action Allow | Out-Null

Write-Host "✔ Port forward ativo: ${ListenAddress}:${HostPort} → ${wslIp}:${WslPort}"
Write-Host "  Regra de firewall '$ruleName' criada."
```

---

## 7. Modo Mirrored (Windows 11 22H2+ / WSL 2.0+)

A partir do **WSL 2.0** (lançado em setembro 2023), existe o modo **Mirrored Networking**:

- O Linux herda as mesmas interfaces de rede do host.
- Serviços no Linux ficam acessíveis via `localhost` tanto do host quanto da LAN.
- **Elimina a necessidade de port forwarding manual.**

### Ativar no `%USERPROFILE%\.wslconfig`

```ini
[wsl2]
networkingMode=mirrored
```

```powershell
# Verificar versão do WSL
wsl --version

# Aplicar a nova configuração
wsl --shutdown
wsl
```

> **Para agentes:** verifique `wsl --version` antes de decidir a estratégia.
> Se `Kernel version >= 5.15.90` e `WSL version >= 2.0.0`, prefira o modo mirrored.

- Referência: [Mirrored Mode Networking - WSL Docs](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking)

---

## 8. Diagnóstico Rápido — Checklist

```powershell
# ── 1. WSL está rodando?
wsl --list --running

# ── 2. IP da VM
wsl -- ip -4 addr show eth0

# ── 3. Interface do host
Get-NetIPAddress -InterfaceAlias "vEthernet (WSL)" -AddressFamily IPv4

# ── 4. Regras de portproxy ativas
netsh interface portproxy show all

# ── 5. Regras de firewall relacionadas a WSL
Get-NetFirewallRule | Where-Object DisplayName -like "*WSL*"

# ── 6. Testar conectividade host → VM
$ip = (wsl -- ip -4 addr show eth0 | Select-String '(\d+\.\d+\.\d+\.\d+)' |
  ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1)
Test-NetConnection -ComputerName $ip -Port 22
```

---

## 9. Referências Consolidadas

| Tema | URL |
|---|---|
| WSL Networking overview | https://learn.microsoft.com/en-us/windows/wsl/networking |
| WSL 2 vs WSL 1 | https://learn.microsoft.com/en-us/windows/wsl/compare-versions |
| netsh portproxy | https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-interface-portproxy |
| New-NetFirewallRule | https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule |
| Get-NetAdapter | https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter |
| Get-NetIPAddress | https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netipaddress |
| Get-NetRoute | https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netroute |
| Mirrored Mode Networking | https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking |
| .wslconfig reference | https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconfig |
