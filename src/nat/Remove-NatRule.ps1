#>

if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\core\Logger.ps1"
}

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
    try {
        Stop-Service -Name 'winnat' -Force -ErrorAction Stop
    }
    catch {
        Write-Log "Stop-Service falhou: $($_.Exception.Message)" "WARN"
    }

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
    }
    else {
        Write-Log "winnat travado '$final'. Reboot recomendado." "ERROR"
    }
}

function Remove-WinRouterNatRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$NatRule,

        [switch]$AllowNukeFallback
    )

    $NatName = $NatRule.Name
    Write-Log "Removendo: '$NatName' (Active=$($NatRule.Active))" "INFO"

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
        }
        else {
            Write-Log "Regra '$NatName' nao encontrada." "INFO"
        }
    }
    catch {
        Write-Log "Erro CIM Remove-NetNat: $($_.Exception.Message)" "WARN"
        if ($AllowNukeFallback) {
            Write-Log "Fallback: remove todas + recria demais..." "INFO"

            $allNats = @(Get-NetNat -ErrorAction SilentlyContinue)
            $otherNats = $allNats | Where-Object { $_.Name -ne $NatName }
            try {
                Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
                Write-Log "Fallback Remove-NetNat (todas) OK." "INFO"
            }
            catch {
                Write-Log "Fallback falhou: $($_.Exception.Message)" "ERROR"
            }

            foreach ($other in $otherNats) {
                try {
                    New-NetNat -Name $other.Name `
                        -InternalIPInterfaceAddressPrefix $other.InternalIPInterfaceAddressPrefix `
                        -ErrorAction Stop
                    Write-Log "Recriada: $($other.Name)" "SUCCESS"
                }
                catch {
                    Write-Log "Erro recriar '$($other.Name)': $($_.Exception.Message)" "WARN"
                }
            }
        }
        else {
            Write-Log "A remoção direta da regra NAT falhou. O fallback agressivo não foi habilitado." "ERROR"
            Write-Host "Could not remove NAT rule '$NatName' directly. A system reboot might be required to clear the state." -ForegroundColor Red
        }
    }

    # [2/3] IPEnableRouter = 0
    Write-Log "[2/3] IPEnableRouter = 0..." "INFO"
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
            -Name "IPEnableRouter" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Log "IPEnableRouter = 0 OK." "SUCCESS"
    }
    catch {
        Write-Log "Erro registro: $($_.Exception.Message)" "ERROR"
    }

    # [3/3] WinNAT startup + netsh reset
    Write-Log "[3/3] WinNAT startup + reset TCP/IP..." "INFO"
    $remainingNats = @(Get-NetNat -ErrorAction SilentlyContinue)
    Write-Log "Regras ATIVAS restantes: $($remainingNats.Count)" "INFO"

    if ($remainingNats.Count -eq 0) {
        Write-Log "Sem regras ativas. WinNAT permanece desabilitado." "SUCCESS"
    }
    else {
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
    $natFinal = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
    $svcFinal = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue
    $routerFinal = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter

    $success = $false
    if ($null -eq $natFinal) {
        Write-Log "OK: Regra '$NatName' removida da lista." "SUCCESS"
        $success = $true
    }
    elseif ($natFinal.Active -eq $false) {
        Write-Log "OK: Regra '$NatName' inativa (Active=False). NAT desabilitado." "SUCCESS"
        Write-Log "    Cache fantasma sera limpo apos reboot (netsh reset executado)." "INFO"
        $success = $true
    }
    else {
        Write-Log "FALHA: Regra '$NatName' ainda ATIVA!" "ERROR"
    }

    Write-Log "IPEnableRouter final: $routerFinal" "INFO"
    Write-Log "WinNAT final: $($svcFinal.Status) / $($svcFinal.StartType)" "INFO"

    if ($success) {
        Write-Host "SUCESSO: NAT '$NatName' desabilitado!" -ForegroundColor Green
        Write-Host "Recomendado: reinicie o PC para limpar cache fantasma." -ForegroundColor Yellow
    }
    else {
        Write-Host "FALHA: Regra '$NatName' ainda ativa!" -ForegroundColor Red
        Write-Host "Execute: sc config winnat start= disabled && reboot" -ForegroundColor Yellow
    }
}
