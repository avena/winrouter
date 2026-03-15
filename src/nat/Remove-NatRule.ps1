#>

if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\..\core\Logger.ps1"
}

function Get-NatRuleStatus {
    <#
    .SYNOPSIS
    Retorna objeto enriquecido com status real da regra NAT.
    Portado de check_nat_install_network_remove.ps1.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$NatName
    )

    $rule = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue

    if ($null -eq $rule) {
        return [PSCustomObject]@{
            Exists      = $false
            Active      = $false
            StatusLabel = '[NAO EXISTE]'
            StatusColor = 'Gray'
            Rule        = $null
        }
    }

    $isActive = ($rule.Active -eq $true)
    $label = if ($isActive) { '[ATIVA]' } else { '[INATIVA]' }
    $color = if ($isActive) { 'Green' } else { 'Gray' }

    return [PSCustomObject]@{
        Exists      = $true
        Active      = $isActive
        StatusLabel = $label
        StatusColor = $color
        Rule        = $rule
    }
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

    # Deteccao precoce: KERNEL DRIVER em StopPending com PID=0
    # Nenhum metodo userland consegue forcar — poupa 12s de tentativas inuteis
    if ($svc.Status -eq 'StopPending') {
        $scOut = & sc.exe queryex winnat 2>&1
        $pidMatch = ($scOut | Select-String -Pattern "PID\s*:\s*(\d+)")
        $kPID = if ($pidMatch) { [int]$pidMatch.Matches[0].Groups[1].Value } else { -1 }

        if ($kPID -eq 0) {
            Write-Log "KERNEL DRIVER StopPending + PID=0. Parada forcada impossivel sem reboot." "WARN"
            Write-Log "Prosseguindo sem tentar parar (sera limpo no reboot)." "WARN"
            return
        }
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

function Remove-InactiveNatRule {
    <#
    .SYNOPSIS
    Remove uma regra NAT que ja esta inativa (Active=False).
    Evita tentativas desnecessarias de parar o winnat travado.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$NatName
    )

    Write-Log "=== Remocao de regra INATIVA: '$NatName' ===" "INFO"

    # Tentativa 1: Remove-NetNat normal (pode funcionar se CIM ainda responde)
    $removedViaCim = $false
    try {
        Remove-NetNat -Name $NatName -Confirm:$false -ErrorAction Stop
        Write-Log "Removida via Remove-NetNat (CIM)." "SUCCESS"
        $removedViaCim = $true
    }
    catch {
        Write-Log "Remove-NetNat falhou: $($_.Exception.Message)" "WARN"
    }

    # Tentativa 2: CIM direto via MSFT_NetNat
    if (-not $removedViaCim) {
        try {
            $cimRule = Get-CimInstance -Namespace 'root/StandardCimv2' `
                -ClassName 'MSFT_NetNat' -ErrorAction Stop |
            Where-Object { $_.Name -eq $NatName }

            if ($cimRule) {
                $cimRule | Remove-CimInstance -ErrorAction Stop
                Write-Log "Removida via CIM direto (MSFT_NetNat)." "SUCCESS"
                $removedViaCim = $true
            }
        }
        catch {
            Write-Log "CIM direto falhou: $($_.Exception.Message)" "WARN"
        }
    }

    # Tentativa 3: Registro — caminho de last resort para driver travado
    if (-not $removedViaCim) {
        Write-Log "Tentando remocao via registro..." "WARN"

        $regPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\winnat\Parameters\NATState\$NatName",
            "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\NAT\$NatName"
        )

        $removedViaReg = $false
        foreach ($path in $regPaths) {
            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    Write-Log "Removida via registro: $path" "WARN"
                    $removedViaReg = $true
                }
                catch {
                    Write-Log "Falha registro '$path': $($_.Exception.Message)" "ERROR"
                }
            }
        }

        if (-not $removedViaReg) {
            Write-Log "Registro nao encontrado. Regra sera limpa no reboot." "WARN"
        }
    }

    # Garante winnat desabilitado (previne reativacao automatica no boot)
    & sc.exe config winnat start= disabled 2>&1 | Out-Null
    Write-Log "WinNAT marcado como disabled." "INFO"

    # IPEnableRouter = 0
    try {
        Set-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
            -Name "IPEnableRouter" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Log "IPEnableRouter = 0 OK." "SUCCESS"
    }
    catch {
        Write-Log "Erro ao setar IPEnableRouter: $($_.Exception.Message)" "ERROR"
    }

    # Verificacao final com 3 niveis
    $natFinal = Get-NatRuleStatus -NatName $NatName
    $svcFinal = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue

    # Retry IPEnableRouter (pode ter delay pos-netsh)
    $routerFinal = $null
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Milliseconds 500
        $routerFinal = (Get-ItemProperty `
                -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
                -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter
        if ($null -ne $routerFinal) { break }
    }

    Write-Log "=== VERIFICACAO FINAL ===" "INFO"
    Write-Log "IPEnableRouter final: $(if ($null -eq $routerFinal) { 'nao lido' } else { $routerFinal })" "INFO"
    Write-Log "WinNAT final: $($svcFinal.Status) / $($svcFinal.StartType)" "INFO"

    if (-not $natFinal.Exists) {
        Write-Log "SUCESSO TOTAL: '$NatName' removida completamente." "SUCCESS"
        $successLevel = "FULL"
    }
    elseif (-not $natFinal.Active -and $svcFinal.StartType -eq 'Disabled') {
        Write-Log "SUCESSO PARCIAL: '$NatName' inativa + winnat desabilitado. Limpar no reboot." "SUCCESS"
        $successLevel = "PARTIAL"
    }
    else {
        Write-Log "FALHA: '$NatName' ainda ativa ou winnat nao desabilitado." "ERROR"
        $successLevel = "FAILED"
    }

    # Output para o caller
    return [PSCustomObject]@{
        NatName      = $NatName
        SuccessLevel = $successLevel
        NatFinal     = $natFinal
        SvcFinal     = $svcFinal
        RouterFinal  = $routerFinal
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

    # === PASSO 2A: Leitura de status ANTES de qualquer acao ===
    $status = Get-NatRuleStatus -NatName $NatName
    Write-Log "Regra '$NatName': $($status.StatusLabel) (Exists=$($status.Exists))" "INFO"

    if (-not $status.Exists) {
        Write-Log "Regra '$NatName' nao existe. Nada a fazer." "INFO"
        return
    }

    # === PASSO 2B: Bifurcacao por estado ===
    if (-not $status.Active) {
        Write-Log "Regra INATIVA detectada. Usando caminho rapido (sem parar winnat)." "INFO"
        Remove-InactiveNatRule -NatName $NatName
        return
    }

    # Se chegou aqui, regra esta ATIVA — fluxo completo
    Write-Log "Regra ATIVA. Iniciando fluxo completo de remocao..." "INFO"

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
    $remainingNats = @(
        Get-NetNat -ErrorAction SilentlyContinue |
        Where-Object { $_.Active -eq $true -and $_.Name -ne $NatName }
    )
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
    $natFinal = Get-NatRuleStatus -NatName $NatName
    $svcFinal = Get-Service -Name 'winnat' -ErrorAction SilentlyContinue

    # Retry IPEnableRouter (pode ter delay pos-netsh)
    $routerFinal = $null
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Milliseconds 500
        $routerFinal = (Get-ItemProperty `
                -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
                -Name 'IPEnableRouter' -ErrorAction SilentlyContinue).IPEnableRouter
        if ($null -ne $routerFinal) { break }
    }

    Write-Log "IPEnableRouter final: $(if ($null -eq $routerFinal) { 'nao lido' } else { $routerFinal })" "INFO"
    Write-Log "WinNAT final: $($svcFinal.Status) / $($svcFinal.StartType)" "INFO"

    if (-not $natFinal.Exists) {
        Write-Log "SUCESSO TOTAL: '$NatName' removida completamente." "SUCCESS"
        $successLevel = "FULL"
    }
    elseif (-not $natFinal.Active -and $svcFinal.StartType -eq 'Disabled') {
        Write-Log "SUCESSO PARCIAL: '$NatName' inativa + winnat desabilitado. Limpar no reboot." "SUCCESS"
        $successLevel = "PARTIAL"
    }
    else {
        Write-Log "FALHA: '$NatName' ainda ativa ou winnat nao desabilitado." "ERROR"
        $successLevel = "FAILED"
    }

    if ($successLevel -eq "FULL") {
        Write-Host "SUCESSO TOTAL: NAT '$NatName' removida completamente!" -ForegroundColor Green
        Write-Host "Recomendado: reinicie o PC para limpar cache fantasma." -ForegroundColor Yellow
    }
    elseif ($successLevel -eq "PARTIAL") {
        Write-Host "SUCESSO PARCIAL: NAT '$NatName' inativa + winnat desabilitado." -ForegroundColor Green
        Write-Host "Recomendado: reinicie o PC para limpar cache fantasma." -ForegroundColor Yellow
    }
    else {
        Write-Host "FALHA: Regra '$NatName' ainda ativa!" -ForegroundColor Red
        Write-Host "Execute: sc config winnat start= disabled && reboot" -ForegroundColor Yellow
    }
}
