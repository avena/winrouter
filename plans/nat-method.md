# WinNAT Method Specification

## Visão Geral

Este documento especifica o método **validado em produção** para configuração de NAT no Windows usando a stack `WinNAT + NetNat`, sem Hyper-V ou ICS.

---

## Scripts de Referência

- `old-base-script/Configurar-NAT-Rede50.ps1` — Método com valores fixos
- `old-base-script/nat-rede50-desktop.ps1` — Método interativo com detecção de interfaces

---

## Pipeline de Componentes (Ordem Obrigatória)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. WinNAT Service (DEVE estar ativo antes de operacoes NetNat)
│    Set-Service WinNAT -StartupType Automatic                │
│    Start-Service WinNAT                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Clean Slate Removal (SEMPRE remove TODAS, sem filtro)    │
│    Get-NetNat | Remove-NetNat -Confirm:$false               │
│    Start-Sleep -Seconds 2                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Create New Rule (única tentativa, sem retry)             │
│    New-NetNat -Name $Name                                   │
│        -InternalIPInterfaceAddressPrefix $Prefix            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. IP Forwarding (registro, efeito imediato)                │
│    Set-ItemProperty "HKLM:\...\Tcpip\Parameters"            │
│        -Name "IPEnableRouter" -Value 1                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Regras (Não Negociáveis)

### Regra 1 — Remoção Total

```powershell
Get-NetNat | Remove-NetNat -Confirm:$false
```

**Nunca** filtrar por prefixo ou nome. WinNAT suporta apenas 1 regra NAT confiavelmente. Qualquer regra residual bloqueia `New-NetNat`.

---

### Regra 2 — Sem SuccessLevel como Gate

Se `Remove-NetNat` não lançou exceção, a remoção funcionou.

**Não verifique** `SuccessLevel` antes de criar nova regra.

```powershell
# ✅ CORRETO
try {
    Get-NetNat | Remove-NetNat -Confirm:$false -ErrorAction Stop
}
catch {
    # Trata erro real
}
```

---

### Regra 3 — Sem Retry Loop

Se `New-NetNat` falha após remoção correta + WinNAT ativo, o problema é **estado do SO**, não timing.

Um único `try/catch` é suficiente.

```powershell
# ✅ CORRETO — Única tentativa
try {
    New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $Prefix
}
catch {
    if ($_.Exception.Message -match 'StopPending|not supported') {
        throw "WinNAT travado. Reboot necessário."
    }
    throw
}
```

---

### Regra 4 — StopPending é o Único Caso Especial

```powershell
if ($errMsg -match 'StopPending|nao ha suporte|not supported') {
    throw "WinNAT driver travado. Execute: Restart-Computer."
}
```

**Por que:** Driver kernel em estado `StopPending` não responde a nenhuma operação userland.

---

### Regra 5 — Sleep ≤ 2 Segundos

`Start-Sleep -Seconds 2` após remoção é suficiente.

Valores maiores indicam problema de design.

---

## Contratos de Função

### New-WinRouterNatRule

**Entrada:**
- `Name`: string — identificador da regra NAT
- `InternalIPInterfaceAddressPrefix`: string CIDR — ex: `"192.168.50.0/24"`

**Saída:**
- `$true` — regra criada com sucesso
- `throw` — qualquer falha, com mensagem descritiva

**Efeitos Colaterais Esperados:**
- Serviço WinNAT ativo e configurado como `Automatic`
- Todas regras NetNat anteriores removidas
- Nova regra NetNat ativa para o prefixo informado

**Efeitos Colaterais Proibidos:**
- ❌ Não deve configurar IP em nenhuma interface
- ❌ Não deve modificar rotas
- ❌ Não deve alterar firewall

---

### Remove-WinRouterNatRule

**Entrada:**
- `NatRule`: psobject — objeto da regra NAT (vindo de `Get-NetNat`)

**Saída:**
- void (sem retorno)
- `throw` apenas se estado `StopPending` detectado

**Efeitos Colaterais Esperados:**
- Serviço WinNAT ativo
- Todas regras NetNat removidas

**Efeitos Colaterais Proibidos:**
- ❌ Não deve desabilitar serviço WinNAT permanentemente
- ❌ Não deve chamar `netsh reset`
- ❌ Não deve modificar registro (IPEnableRouter)

---

## Checklist de Validação

Antes de considerar uma implementação como correta:

- [ ] `Get-NetNat` retorna exatamente 1 regra com prefixo correto
- [ ] Regra tem `Active = True`
- [ ] **NÃO** existe lógica de filtro por prefixo na remoção
- [ ] **NÃO** existe loop de retry em volta de `New-NetNat`
- [ ] **NÃO** existe classificação de erro de IPv6 como caso especial
- [ ] Único caso especial tratado é `StopPending/not supported`
- [ ] Função **NÃO** configura IPs (sem `New-NetIPAddress` dentro dela)
- [ ] `Start-Sleep` após remoção é ≤ 2 segundos
- [ ] **NÃO** desabilita serviço WinNAT permanentemente
- [ ] **NÃO** chama `netsh reset` como parte do fluxo normal

---

## Antipadrões (NÃO IMPLEMENTAR)

### ❌ Antipadrão 1: Remoção Filtrada por Prefixo

```powershell
# NUNCA FAZER ISSO
Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq "192.168.50.0/24" } | Remove-NetNat
```

**Problema:** Deixa regras de outros prefixos que bloqueiam `New-NetNat`.

---

### ❌ Antipadrão 2: SuccessLevel como Gate

```powershell
# NUNCA FAZER ISSO
$removeResult = Remove-WinRouterNatRule -NatRule $existing
if ($removeResult.SuccessLevel -ne 'FULL') {
    throw "Remoção incompleta"
}
```

**Problema:** `Remove-NetNat` é idempotente. Se não lançou exceção, funcionou.

---

### ❌ Antipadrão 3: Retry Loop em New-NetNat

```powershell
# NUNCA FAZER ISSO
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $Prefix
        break
    }
    catch {
        Start-Sleep -Seconds 3
    }
}
```

**Problema:** Falha repetida = problema de estado do SO, não de timing.

---

### ❌ Antipadrão 4: Classificação de Erro IPv6

```powershell
# NUNCA FAZER ISSO
$isIPv6Issue = $errMsg -match 'IPv6' -and -not $isWinnatDead
if ($isIPv6Issue) {
    Write-Log "Erro real de IPv6: $errMsg" "ERROR"
    throw "Problema de IPv6: $errMsg"
}
```

**Problema:** Erros com "IPv6" são sintoma de WinNAT em estado ruim, não causa.

---

### ❌ Antipadrão 5: Fallback com netsh Reset

```powershell
# NUNCA FAZER ISSO
if ($removeFailed) {
    & netsh int ip reset
    & netsh winsock reset
}
```

**Problema:** Efeitos colaterais indesejados. Se remoção falha, reboot é única solução.

---

### ❌ Antipadrão 6: Desabilitar WinNAT Permanentemente

```powershell
# NUNCA FAZER ISSO
& sc.exe config winnat start= disabled
```

**Problema:** WinNAT é necessário para operações futuras.

---

### ❌ Antipadrão 7: Múltiplas Tentativas de Remoção (CIM, Registro, PID)

```powershell
# NUNCA FAZER ISSO
# Tentativa 1: Remove-NetNat
# Tentativa 2: CIM direto via MSFT_NetNat
# Tentativa 3: Registro
# Tentativa 4: taskkill PID
# ...
```

**Problema:** Se `Remove-NetNat` falha com StopPending, nenhuma alternativa userland funciona.

---

## Troubleshooting

### Erro: "StopPending" ou "not supported"

**Causa:** Driver kernel WinNAT travado

**Solução:**
```powershell
Restart-Computer -Force
```

---

### Erro: "already exists"

**Causa:** Remoção anterior incompleta

**Solução:**
```powershell
# Execute remoção novamente
Get-NetNat | Remove-NetNat -Confirm:$false

# Se persistir, reboot
Restart-Computer -Force
```

---

### Regra criada mas Active = False

**Causa:** WinNAT não estava ativo durante criação

**Solução:**
```powershell
# Garanta WinNAT ativo antes de criar
Set-Service WinNAT -StartupType Automatic
Start-Service WinNAT
New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $Prefix
```

---

## Referências

- **Scripts de Referência:**
  - `old-base-script/Configurar-NAT-Rede50.ps1`
  - `old-base-script/nat-rede50-desktop.ps1`

- **Documentação Relacionada:**
  - `docs/NAT_FIX_SUMMARY.md` — Resumo completo do fix
  - `GEMINI.md` — Guidelines do projeto (seção NAT)
  - `docs/DEVELOPMENT.md` — Guia de desenvolvimento

- **Origem:**
  - Conversa Claude — "Configuração NAT WinNAT no Windows" (2026-03-15)
