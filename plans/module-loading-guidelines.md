# PowerShell Module Loading Guidelines

## Contexto

Este documento descreve as práticas corretas para carregamento de módulos no WinRouter, especificamente sobre o uso de `Export-ModuleMember`.

---

## Problema: Export-ModuleMember em Arquivos .ps1

### Erro Comum

```powershell
# ❌ NUNCA FAZER ISSO em arquivos .ps1 carregados via dot-sourcing
# Arquivo: src/core/Utils.ps1 (ou qualquer .ps1 em src/)

function Get-NatRuleName {
    # ...
}

Export-ModuleMember -Function Get-NatRuleName  # ❌ ERRO!
```

### Mensagem de Erro

```
Export-ModuleMember: C:\Users\adminrandom\Estudos\winrouter\src\core\Utils.ps1:122
Line |
 122 |  Export-ModuleMember -Function Get-NatRuleName, ...
     |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | The Export-ModuleMember cmdlet can only be called from inside a module.
```

---

## Causa Raiz

`Export-ModuleMember` **só funciona dentro de arquivos `.psm1`** (PowerShell Script Module).

No WinRouter, os arquivos `.ps1` em `src/` são carregados via **dot-sourcing** dentro do `WinRouter.psm1`:

```powershell
# WinRouter.psm1
. "$PSScriptRoot\core\Utils.ps1"  # Dot-source, NÃO é um módulo independente
```

Quando um arquivo `.ps1` é carregado via dot-sourcing:
- Ele é executado no escopo do módulo pai (`WinRouter.psm1`)
- `Export-ModuleMember` dentro do `.ps1` falha porque o arquivo não é um módulo
- As funções são automaticamente disponíveis no escopo do módulo pai

---

## Solução Correta

### Em Arquivos `.ps1` (src/core/, src/nat/, etc.)

```powershell
# ✅ CORRETO - Apenas definir funções, sem export
# Arquivo: src/core/Utils.ps1

function Get-NatRuleName {
    <# .SYNOPSIS ... #>
    param()
    # Implementação
}

function Test-IsOwnedNatRule {
    <# .SYNOPSIS ... #>
    param()
    # Implementação
}

# ❌ NÃO adicionar Export-ModuleMember aqui
# ✅ As funções são exportadas pelo WinRouter.psm1
```

### No Módulo Principal (`WinRouter.psm1`)

```powershell
# ✅ CORRETO - Exportar no módulo pai
# Arquivo: src/WinRouter.psm1

# Carregar todos os módulos via dot-source
. "$PSScriptRoot\core\Utils.ps1"
. "$PSScriptRoot\nat\New-NatRule.ps1"
# ... outros módulos

# Exportar todas as funções carregadas
Export-ModuleMember -Function *
```

---

## Arquitetura de Módulos WinRouter

```
winrouter/
├── src/
│   ├── WinRouter.psm1         # ← ÚNICO arquivo .psm1 (módulo principal)
│   │                          #    - Carrega todos os .ps1 via dot-source
│   │                          #    - Contém Export-ModuleMember -Function *
│   │
│   ├── core/
│   │   ├── Logger.ps1         # ← .ps1 carregado via dot-source
│   │   ├── Elevation.ps1      #    - Apenas define funções
│   │   └── Utils.ps1          #    - SEM Export-ModuleMember
│   │
│   ├── nat/
│   │   ├── New-NatRule.ps1    # ← .ps1 carregado via dot-source
│   │   ├── Remove-NatRule.ps1 #    - Apenas define funções
│   │   └── Get-NatStatus.ps1  #    - SEM Export-ModuleMember
│   │
│   └── ... (outros .ps1)
```

---

## Checklist para Novos Arquivos .ps1

Ao criar um novo arquivo `.ps1` em `src/`:

- [ ] O arquivo contém apenas definições de funções (`function Name { }`)
- [ ] **NÃO** contém `Export-ModuleMember`
- [ ] **NÃO** contém `param()` no nível do script (apenas dentro das funções)
- [ ] As funções têm help documentation (`.SYNOPSIS`, `.DESCRIPTION`, etc.)
- [ ] O arquivo será carregado no `WinRouter.psm1` via dot-source

---

## Exemplo Completo

### ✅ CORRETO: `src/core/Exemplo.ps1`

```powershell
# Exemplo.ps1 - Módulo utilitário
# Carregado via dot-source em WinRouter.psm1

function Get-ExemploData {
    <#
    .SYNOPSIS
    Retorna dados de exemplo.
    
    .PARAMETER Name
    Nome do dado a retornar.
    
    .EXAMPLE
    Get-ExemploData -Name "Teste"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return "Dados: $Name"
}

function Set-ExemploConfig {
    <#
    .SYNOPSIS
    Configura dados de exemplo.
    #>

    [CmdletBinding()]
    param(
        [string]$Config
    )

    # Implementação
}

# ✅ SEM Export-ModuleMember aqui
# As funções são exportadas automaticamente pelo WinRouter.psm1
```

### ✅ CORRETO: `src/WinRouter.psm1`

```powershell
# WinRouter.psm1 - Módulo principal

# Carregar módulos core
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\Elevation.ps1"
. "$PSScriptRoot\core\Exemplo.ps1"  # ← Dot-source

# Carregar outros módulos
. "$PSScriptRoot\nat\New-NatRule.ps1"
# ...

# Exportar TODAS as funções carregadas
Export-ModuleMember -Function *

# Metadata do módulo
$script:ModuleVersion = "1.0.0"
```

---

## Perguntas Frequentes

### P: Posso criar um módulo .psm1 separado para Utils?

**R:** Sim, mas não é recomendado no WinRouter. A arquitetura atual usa um único módulo principal (`WinRouter.psm1`) que carrega todos os `.ps1` via dot-source. Isso simplifica:

- Carregamento de módulos (apenas 1 import)
- Compartilhamento de funções entre módulos
- Logging centralizado

### P: Como testar funções de um arquivo .ps1 isoladamente?

**R:** Use dot-source direto no PowerShell:

```powershell
# Testar função isoladamente
. "src\core\Utils.ps1"
Get-NatRuleName -NetworkPrefix "192.168.60.0/24"
```

### P: E se eu quiser exportar apenas algumas funções?

**R:** No `WinRouter.psm1`, especifique as funções:

```powershell
# Exportar apenas funções específicas
Export-ModuleMember -Function Get-NatRuleName, Test-IsOwnedNatRule
```

---

## Histórico

### 2026-03-16 — Correção do Export-ModuleMember

**Problema:** `src/core/Utils.ps1` continha `Export-ModuleMember`, causando erro ao carregar.

**Solução:** Removido `Export-ModuleMember` do arquivo `.ps1`. Funções são exportadas pelo `WinRouter.psm1`.

**Lição:** Arquivos `.ps1` carregados via dot-source **NUNCA** devem conter `Export-ModuleMember`.

---

## Referências

- [Microsoft Docs: Export-ModuleMember](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/export-modulemember)
- [Microsoft Docs: Module Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/module-best-practices)
- `GEMINI.md` — Diretrizes gerais do projeto WinRouter
