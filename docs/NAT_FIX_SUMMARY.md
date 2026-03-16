# NAT Fix Summary - Método Validado WinNAT

## Resumo Executivo

Este documento descreve o método **validado em produção** para configuração de NAT no Windows usando a stack `WinNAT + NetNat`, sem Hyper-V ou ICS. Baseado nos scripts de referência `Configurar-NAT-Rede50.ps1` e `nat-rede50-desktop.ps1`.

---

## Problemas Históricos

### Erros Comuns (ANTES do Fix)

```
WARNING: NAT rule with same prefix already exists. Removing before re-creation...
Remove-NetNat: Não há suporte à operação solicitada.
New-WinRouterNatRule: Failed to create NAT rule: IPV6 sem suporte.
New-NetNat: IPV6 sem suporte.
```

### Causa Raiz

1. **Remoção seletiva por prefixo** - Filtrava regras antes de remover, deixando regras residuais
2. **SuccessLevel como gate** - Verificação complexa desnecessária antes de criar nova regra
3. **Retry loop em New-NetNat** - Máscara erro real de estado do SO
4. **Classificação de erro IPv6** - Erros de IPv6 são sintoma, não causa
5. **Código excessivamente complexo** - ~300 linhas onde ~80 são suficientes

---

## Solução Implementada

### 1. Método "Clean Slate" (Remoção Total)

**ANTES (ERRADO):**

```powershell
# ❌ ANTIPADRÃO - Filtra por prefixo específico
Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $prefix } | Remove-NetNat
```

**DEPOIS (CORRETO):**

```powershell
# ✅ METODO VALIDADO - Remove TODAS as regras
Get-NetNat | Remove-NetNat -Confirm:$false
Start-Sleep -Seconds 2
```

### 2. Simplificação do Código

| Arquivo              | Antes       | Depois      | Redução |
| -------------------- | ----------- | ----------- | ------- |
| `New-NatRule.ps1`    | ~90 linhas  | ~60 linhas  | 33%     |
| `Remove-NatRule.ps1` | ~300 linhas | ~80 linhas  | 73%     |
| `start-network.ps1`  | ~306 linhas | ~289 linhas | 6%      |

### 3. IPv6 Explicitamente Não Suportado

**Decisão de Design:** IPv6 não é suportado para operações NAT porque:

- Compatibilidade varia entre versões do Windows
- Erros frequentes ("IPV6 sem suporte")
- Maioria dos usuários precisa apenas de IPv4
- Remove complexidade desnecessária

---

## Pipeline Obrigatório (Ordem Imutável)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. WinNAT Service (DEVE estar ativo antes de NetNat)        │
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

## Regras Não Negociáveis

| #   | Regra                            | Justificativa                                |
| --- | -------------------------------- | -------------------------------------------- |
| 1   | Remoção total, sem filtro        | WinNAT suporta apenas 1 regra confiavelmente |
| 2   | Sem SuccessLevel como gate       | Remove-NetNat é idempotente                  |
| 3   | Sem retry loop em New-NetNat     | Falha = problema de estado do SO             |
| 4   | Único caso especial: StopPending | Driver kernel travado → reboot               |
| 5   | Sleep pós-remoção ≤ 2s           | Mais que isso mascara erro real              |

---

## 🚫 ANTIPADRÕES (NÃO IMPLEMENTAR)

### Antipadrão 1: Remoção Filtrada por Prefixo

```powershell
# ❌ NUNCA FAZER ISSO
Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq "192.168.50.0/24" } | Remove-NetNat
```

**Por que é errado:**

- WinNAT suporta apenas 1 regra NAT
- Qualquer regra residual bloqueia `New-NetNat`
- Filtrar por prefixo deixa regras de outros prefixos que causam conflito

**Solução correta:**

```powershell
# ✅ SEMPRE remover TODAS
Get-NetNat | Remove-NetNat -Confirm:$false
```

---

### Antipadrão 2: SuccessLevel como Gate

```powershell
# ❌ NUNCA FAZER ISSO
$removeResult = Remove-WinRouterNatRule -NatRule $existing
if ($removeResult.SuccessLevel -ne 'FULL') {
    throw "Remoção incompleta"
}
```

**Por que é errado:**

- `Remove-NetNat` é idempotente
- Se não lançou exceção, a remoção funcionou
- SuccessLevel adiciona complexidade sem benefício

**Solução correta:**

```powershell
# ✅ Apenas tente remover, se falhar o catch trata
try {
    Get-NetNat | Remove-NetNat -Confirm:$false -ErrorAction Stop
}
catch {
    # Trata erro real
}
```

---

### Antipadrão 3: Retry Loop em New-NetNat

```powershell
# ❌ NUNCA FAZER ISSO
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

**Por que é errado:**

- Se `New-NetNat` falha após remoção correta + WinNAT ativo, o problema é estado do SO
- Retry mascara o erro real
- Não resolve problema de driver travado

**Solução correta:**

```powershell
# ✅ Única tentativa, erro claro
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

### Antipadrão 4: Classificação de Erro IPv6

```powershell
# ❌ NUNCA FAZER ISSO
$isIPv6Issue = $errMsg -match 'IPv6' -and -not $isWinnatDead
if ($isIPv6Issue) {
    Write-Log "Erro real de IPv6: $errMsg" "ERROR"
    throw "Problema de IPv6: $errMsg"
}
```

**Por que é errado:**

- Erros com "IPv6" na mensagem são sintoma de WinNAT em estado ruim
- Não é causa independente
- Tratamento especial cria falsa impressão de que IPv6 é suportado

**Solução correta:**

```powershell
# ✅ Único caso especial: StopPending
if ($errMsg -match 'StopPending|nao ha suporte|not supported') {
    throw "WinNAT travado. Reboot necessário."
}
# Outros erros: lança com mensagem original
throw
```

---

### Antipadrão 5: Fallback Agressivo com netsh Reset

```powershell
# ❌ NUNCA FAZER ISSO
if ($removeFailed) {
    & netsh int ip reset
    & netsh winsock reset
    # ... mais 10 linhas de força bruta
}
```

**Por que é errado:**

- `netsh reset` tem efeitos colaterais indesejados
- Adiciona complexidade desnecessária
- Se remoção falha, o problema é driver travado → reboot é a única solução

**Solução correta:**

```powershell
# ✅ Se falhou, verifica se é StopPending e orienta reboot
catch {
    if ($errMsg -match 'StopPending') {
        throw "Reboot necessário"
    }
    # Loga erro e continua (idempotência)
}
```

---

### Antipadrão 6: Desabilitar Serviço WinNAT Permanentemente

```powershell
# ❌ NUNCA FAZER ISSO
& sc.exe config winnat start= disabled
```

**Por que é errado:**

- WinNAT é necessário para operações NAT futuras
- Desabilitar permanentemente quebra funcionalidade
- Serviço deve ser `Automatic` ou `Demand`

**Solução correta:**

```powershell
# ✅ Manter serviço disponível
Set-Service -Name "WinNAT" -StartupType Automatic
Start-Service -Name "WinNAT"
```

---

### Antipadrão 7: Múltiplas Tentativas de Remoção (CIM, Registro, etc.)

```powershell
# ❌ NUNCA FAZER ISSO
# Tentativa 1: Remove-NetNat
# Tentativa 2: CIM direto via MSFT_NetNat
# Tentativa 3: Registro
# Tentativa 4: taskkill PID
# ...
```

**Por que é errado:**

- Se `Remove-NetNat` falha com StopPending, nenhuma alternativa userland funciona
- Complexidade extrema (~300 linhas) para resolver problema que requer reboot
- Código de fallback é executado raramente, difícil de testar/manter

**Solução correta:**

```powershell
# ✅ Simples e direto
try {
    Get-NetNat | Remove-NetNat -Confirm:$false -ErrorAction Stop
}
catch {
    if ($errMsg -match 'StopPending') {
        throw "Reboot necessário"
    }
    Write-Log "Aviso: $_" "WARN"
}
```

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

## Arquivos Modificados

| Arquivo                         | Mudança                                     |
| ------------------------------- | ------------------------------------------- |
| `src/nat/New-NatRule.ps1`       | Mantido correto (já seguia método validado) |
| `src/nat/Remove-NatRule.ps1`    | Simplificado de ~300 para ~80 linhas        |
| `start-network.ps1`             | Removido código de compatibilidade IPv6     |
| `src/nat/Enable-IPv6ForNat.ps1` | **Deletado** (IPv6 não suportado)           |

---

## Guia Rápido para Desenvolvedores

### Ao implementar funções NAT:

1. **Sempre** comece garantindo WinNAT ativo
2. **Sempre** remova TODAS as regras antes de criar
3. **Nunca** use filtro por prefixo/nome na remoção
4. **Nunca** implemente retry loop
5. **Nunca** classifique erros de IPv6 separadamente
6. **Único caso especial:** `StopPending` → throw com msg de reboot
7. **Sempre** use `Start-Sleep -Seconds 2` após remoção

### Ao revisar código NAT:

Verifique se **NÃO** existe:

- [ ] `Where-Object` filtrando regras NAT antes de remover
- [ ] Variável `SuccessLevel` ou similar
- [ ] Loop `for/while` em volta de `New-NetNat`
- [ ] `if ($errMsg -match 'IPv6')` como caso especial
- [ ] `netsh int ip reset` ou `netsh winsock reset`
- [ ] `sc config winnat start=disabled`

---

## Troubleshooting

### Erro: "StopPending" ou "not supported"

**Causa:** Driver kernel WinNAT travado

**Solução:**

```powershell
Restart-Computer -Force
```

### Erro: "already exists"

**Causa:** Remoção anterior incompleta

**Solução:**

```powershell
# Execute remoção novamente
Get-NetNat | Remove-NetNat -Confirm:$false

# Se persistir, reboot
Restart-Computer -Force
```

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

- **Documentação Técnica:**
  - `plans/nat-method.md` — Especificação completa do método
  - `docs/DEVELOPMENT.md` — Guidelines para desenvolvedores

- **Conversa Original:**
  - Exportação Claude — "Configuração NAT WinNAT no Windows" (2026-03-15)
