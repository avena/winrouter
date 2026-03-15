param([int]$Port=22)

Write-Host "Procurando IP do WSL..." -Foreground Cyan

# Pega linha IP com regex confiavel
$ipLine = wsl -d Ubuntu ip addr show eth0 2>$null | Select-String 'inet ' | Select-Object -First 1

if (-not $ipLine) {
    Write-Error "ERRO: WSL nao encontrado ou sem IP eth0"
    exit 1
}

# Extrai IP: inet 172.22.117.202/20 -> 172.22.117.202
if ($ipLine.Line -match 'inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})') {
    $WSL_IP = $matches[1]
} else {
    Write-Error "ERRO: IP invalido: $($ipLine.Line)"
    exit 1
}

Write-Host "WSL IP: $WSL_IP" -Foreground Green

# Limpa forwards antigos
netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>$null
Remove-NetFirewallRule -DisplayName "WSL SSH $Port" -ErrorAction SilentlyContinue

# Cria forward
netsh interface portproxy add v4tov4 listenport=$Port listenaddress=0.0.0.0 connectport=$Port connectaddress=$WSL_IP
New-NetFirewallRule -DisplayName "WSL SSH $Port" -Direction Inbound -LocalPort $Port -Action Allow -Protocol TCP

# IP Windows
$winIP = (Get-NetIPAddress -AddressFamily IPv4 | ? { $_.InterfaceAlias -match 'Ethernet|Wi-Fi|WiFi' } | Select -First 1).IPAddress
if (-not $winIP) { $winIP = 'IP_WINDOWS' }

Write-Host ""
Write-Host "SUCESSO! SSH forward ativo:" -Foreground Green
Write-Host "Porta $Port --> $WSL_IP" -Foreground Yellow
Write-Host "Comando: ssh usuario@$winIP`:$Port" -Foreground Yellow
Write-Host "Verificar: netsh interface portproxy show v4tov4 listenport=$Port"

