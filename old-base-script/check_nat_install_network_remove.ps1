#!/usr/bin/env pwsh
param(
    [string]$LogFile = "$(Get-Location)\remover-nat-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Host $logLine -ForegroundColor @{INFO='White'; WARN='Yellow'; ERROR='Red'; SUCCESS='Green'}[$Level]
    $logLine | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Auto-elevacao para Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log "Iniciando script. Log: $LogFile" "INFO"

if (-not $isAdmin) {
    Write-Log "Solicitando elevacao..." "WARN"
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit 0
}

Write-Log "Rodando como Admin." "SUCCESS"

# Funcao: Para WinNAT com 4 metodos
function Stop-WinNatForced {
    param([int]$TimeoutSec = 8)
    Write-Log "Stop-WinNatForced (timeout ${TimeoutSec}s)" "INFO"

    $svc = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Log "winnat nao encontrado." "INFO"; return }
    $statusInicial = $svc.Status
    Write-Log "Status inicial: $statusInicial" "INFO"

    if ($statusInicial -eq 'Stopped') {
        Write-Log "winnat ja parado." "INFO"; return
    }

    # [1/4] Stop-Service
    Write-Log "[1/4] Stop-Service..." "INFO"
    $svc.Stop()
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Service -Name 'winnat').Status -ne 'Stopped' -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
    }
    $status1 = (Get-Service -Name 'winnat').Status
    Write-Log "Apos Stop-Service: $status1" "INFO"
    if ($status1 -eq 'Stopped') { Write-Log "OK metodo 1." "SUCCESS"; return }

    # [2/4] sc queryex + taskkill PID
    Write-Log "[2/4] sc queryex PID..." "INFO"
    $scOutput = & sc.exe queryex winnat 2>&1
    Write-Log "sc output: $scOutput" "INFO"
    $pidLine = $scOutput | Select-String -Pattern "PID\s*:\s*(\d+)"
    if ($pidLine) {
        $svcPID = [int]($pidLine.Matches[0].Groups[1].Value)
        Write-Log "PID: $svcPID" "INFO"
        if ($svcPID -gt 0) {
            $killResult = & taskkill /F /PID $svcPID 2>&1
            Write-Log "taskkill PID result: $killResult" "INFO"
            Start-Sleep -Seconds 2
            if ((Get-Service -Name 'winnat').Status -eq 'Stopped') {
                Write-Log "OK metodo 2 (PID $svcPID)." "SUCCESS"; return
            }
        }
    }

    # [3/4] taskkill /FI SERVICES
    Write-Log "[3/4] taskkill /FI..." "INFO"
    $fiResult = & taskkill /F /FI "SERVICES eq winnat" 2>&1
    Write-Log "taskkill /FI: $fiResult" "INFO"
    Start-Sleep -Seconds 2
    if ((Get-Service -Name 'winnat').Status -eq 'Stopped') {
        Write-Log "OK metodo 3." "SUCCESS"; return
    }

    # [4/4] sc.exe stop
    Write-Log "[4/4] sc stop..." "INFO"
    $scStop = & sc.exe stop winnat 2>&1
    Write-Log "sc stop: $scStop" "INFO"
    Start-Sleep -Seconds 2
    $final = (Get-Service -Name 'winnat').Status
    Write-Log "Status FINAL winnat: $final" "INFO"
    if ($final -eq 'Stopped') {
        Write-Log "OK metodo 4." "SUCCESS"
    } else {
        Write-Log "winnat travado '$final'. Reboot recomendado." "ERROR"
    }
}

# Lista regras NAT (inclui ativas e inativas)
Write-Log "Listando regras NAT..." "INFO"
if (-not (Get-Command -Name 'Get-NetNat' -ErrorAction SilentlyContinue)) {
    Write-Log "ERRO: Cmdlets NAT nao encontrados." "ERROR"
    Read-Host "Pressione Enter para sair"; exit 1
}

$nats = @(Get-NetNat -ErrorAction SilentlyContinue)
Write-Log "Regras encontradas: $($nats.Count)" "INFO"

if ($nats.Count -eq 0) {
    Write-Log "Nenhuma regra NAT configurada." "INFO"
    Read-Host "Pressione Enter para sair"; exit 0
}

# Menu numerado com indicacao de ativo/inativo
Write-Host ""
Write-Host "Regras NAT encontradas:" -ForegroundColor Green
Write-Host ""
$index = 1
foreach ($nat in $nats) {
    $activeLabel = if ($nat.Active -eq $true) { "[ATIVA]" } else { "[INATIVA]" }
    $activeColor = if ($nat.Active -eq $true) { "Green" } else { "Gray" }
    Write-Host "($index) $($nat.Name) " -NoNewline
    Write-Host $activeLabel -ForegroundColor $activeColor
    Write-Host "    Internal: $($nat.InternalIPInterfaceAddressPrefix)"
    Write-Host "    External: $($nat.ExternalIPInterfaceAddressPrefix)"
    Write-Host ""
    Write-Log "Regra ${index}: $($nat.Name) [$($nat.InternalIPInterfaceAddressPrefix)] Active=$($nat.Active)" "INFO"
    $index++
}

$choice = Read-Host "Digite numero para remover ou Enter para sair"
Write-Log "Escolha do usuario: '$choice'" "INFO"

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Log "Cancelado pelo usuario." "INFO"
    Read-Host "Pressione Enter para sair"; exit 0
}

if (-not ($choice -as [int])) {
    Write-Log "Opcao invalida: $choice" "ERROR"
    Read-Host "Pressione Enter para sair"; exit 1
}

$idx = [int]$choice
if ($idx -lt 1 -or $idx -gt $nats.Count) {
    Write-Log "Indice invalido: $idx" "ERROR"
    Read-Host "Pressione Enter para sair"; exit 1
}

$natEscolhida = $nats[$idx - 1]
$NatName = $natEscolhida.Name
Write-Log "Removendo: '$NatName' (Active=$($natEscolhida.Active))" "INFO"

# Interface pelo MAC
$MAC = "04-58-5D-21-3B-93"
$adapter = Get-NetAdapter | Where-Object { $_.MacAddress -eq $MAC }
$InterfaceAlias = if ($adapter) { $adapter.Name } else { $null }
Write-Log "Interface: '$InterfaceAlias' (MAC: $MAC)" "INFO"

# Estado inicial
Write-Log "Estado inicial:" "INFO"
Write-Log "  WinNAT: $((Get-Service -Name 'winnat').Status)" "INFO"
$routerInicial = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter
Write-Log "  IPEnableRouter: $routerInicial" "INFO"

# [1/3] Para WinNAT + desabilita + tenta remover
Write-Log "[1/3] Parando e desabilitando WinNAT..." "INFO"
Stop-WinNatForced -TimeoutSec 8

# Desabilita WinNAT ANTES de remover (previne recriacao automatica)
Write-Log "Desabilitando WinNAT (sc config disabled)..." "INFO"
$scDisable = & sc.exe config winnat start= disabled 2>&1
Write-Log "sc config disabled: $scDisable" "INFO"

# Tenta remover a regra escolhida
Write-Log "Removendo regra '$NatName'..." "INFO"
try {
    $natExiste = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
    if ($natExiste) {
        Remove-NetNat -Name $NatName -Confirm:$false -ErrorAction Stop
        Write-Log "Regra '$NatName' removida via Remove-NetNat." "SUCCESS"
    } else {
        Write-Log "Regra '$NatName' nao encontrada." "INFO"
    }
} catch {
    Write-Log "Erro CIM Remove-NetNat: $($_.Exception.Message)" "WARN"
    Write-Log "Fallback: remove todas + recria demais..." "INFO"

    $outrasNats = $nats | Where-Object { $_.Name -ne $NatName }
    try {
        Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Fallback Remove-NetNat (todas) OK." "INFO"
    } catch {
        Write-Log "Fallback falhou: $($_.Exception.Message)" "ERROR"
    }

    foreach ($outra in $outrasNats) {
        try {
            New-NetNat -Name $outra.Name `
                       -InternalIPInterfaceAddressPrefix $outra.InternalIPInterfaceAddressPrefix `
                       -ErrorAction Stop
            Write-Log "Recriada: $($outra.Name)" "SUCCESS"
        } catch {
            Write-Log "Erro recriar '$($outra.Name)': $($_.Exception.Message)" "WARN"
        }
    }
}

# [2/3] IPEnableRouter = 0
Write-Log "[2/3] IPEnableRouter = 0..." "INFO"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
        -Name "IPEnableRouter" -Value 0 -Type DWord -Force -ErrorAction Stop
    Write-Log "IPEnableRouter = 0 OK." "SUCCESS"
} catch {
    Write-Log "Erro registro: $($_.Exception.Message)" "ERROR"
}

# [3/3] WinNAT startup + netsh reset
Write-Log "[3/3] WinNAT startup + reset TCP/IP..." "INFO"
$natsRestantes = @(Get-NetNat -ErrorAction SilentlyContinue | Where-Object { $_.Active -eq $true })
Write-Log "Regras ATIVAS restantes: $($natsRestantes.Count)" "INFO"

if ($natsRestantes.Count -eq 0) {
    Write-Log "Sem regras ativas. WinNAT permanece desabilitado." "SUCCESS"
} else {
    & sc.exe config winnat start= demand 2>&1 | Out-Null
    Start-Service -Name 'winnat' -ErrorAction SilentlyContinue
    Write-Log "WinNAT reabilitado (ha outras regras ativas)." "INFO"
}

# netsh reset para limpar cache kernel / regras fantasmas
Write-Log "netsh int ip reset..." "INFO"
& netsh int ip reset 2>&1 | Out-Null
Write-Log "netsh winsock reset..." "INFO"
& netsh winsock reset 2>&1 | Out-Null
Write-Log "netsh reset OK. Reboot aplica completamente." "WARN"

# Verificacao final
Write-Log "=== VERIFICACAO FINAL ===" "INFO"
$natFinal  = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
$svcFinal  = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue
$routerFinal = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter

# Sucesso = removida OU inativa (Active: False)
$ok = $true
if ($null -eq $natFinal) {
    Write-Log "OK: Regra '$NatName' removida da lista." "SUCCESS"
} elseif ($natFinal.Active -eq $false) {
    Write-Log "OK: Regra '$NatName' inativa (Active=False). NAT desabilitado." "SUCCESS"
    Write-Log "    Cache fantasma sera limpo apos reboot (netsh reset executado)." "INFO"
} else {
    Write-Log "FALHA: Regra '$NatName' ainda ATIVA!" "ERROR"
    $ok = $false
}

Write-Log "IPEnableRouter final: $routerFinal" "INFO"
Write-Log "WinNAT final: $($svcFinal.Status) / $($svcFinal.StartType)" "INFO"

if ($InterfaceAlias) {
    $ipAtual = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress "192.168.50.1" -ErrorAction SilentlyContinue
    Write-Log "IP 192.168.50.1 '$InterfaceAlias': $(if ($ipAtual) { 'mantido' } else { 'nao encontrado' })" "INFO"
}

Write-Host ""
if ($ok) {
    Write-Host "SUCESSO: NAT '$NatName' desabilitado!" -ForegroundColor Green
    Write-Host "Recomendado: reinicie o PC para limpar cache fantasma." -ForegroundColor Yellow
} else {
    Write-Host "FALHA: Regra '$NatName' ainda ativa!" -ForegroundColor Red
    Write-Host "Execute: sc config winnat start= disabled && reboot" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Log salvo: $LogFile" -ForegroundColor Cyan
Write-Host "Para recriar NAT: execute nat-rede50.ps1"
Read-Host "Pressione Enter para sair"
