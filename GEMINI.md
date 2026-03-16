# GEMINI.md

## Project Context

This project is dedicated to refactoring the WinRouter script (`config-nat-multi.ps1`) into a modular, maintainable PowerShell structure.

## Foundational Mandates

- **Architecture & Roadmap:** Strictly follow the modular structure, file responsibilities, and task sequence defined in [plans/plan.md](plans/plan.md).
- **Git Workflow:** Adhere to the tree-like branching strategy and commit conventions outlined in [plans/gitflow.md](plans/gitflow.md).
- **Incremental Implementation:** Modules should be implemented and merged into the integration branch (`refactor/modular-structure`) following the dependency order specified in the GitFlow document.
- **Verification:** Every modular change must be validated for behavioral consistency with the original script before being considered complete.

## Reference Documentation

- [Modularization Plan](plans/plan.md): Contains the target directory structure and detailed task list.
- [GitFlow Strategy](plans/gitflow.md): Contains branching, merging, and rebasing instructions.

## PowerShell Module Development Guidelines

### Module Structure (.psm1 as Orchestrator)

#### What is a .psm1 file?

A `.psm1` file is a PowerShell Script Module that acts as a container for multiple functions and provides a clean interface for module loading. When you use `Import-Module WinRouter.psm1`, PowerShell executes this file and makes all defined functions available in the current session.

#### Two Styles of Module Organization

| Style          | How it works                                           | When to use                    |
| -------------- | ------------------------------------------------------ | ------------------------------ |
| **Monolithic** | All functions written directly within the `.psm1` file | Small, simple modules          |
| **Multi-file** | `.psm1` dot-sources multiple `.ps1` files              | Larger projects like WinRouter |

#### Recommended Multi-file Structure

The WinRouter project uses the multi-file approach where the `.psm1` file serves as an orchestrator:

```powershell
# src/WinRouter.psm1

# Core modules
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\Elevation.ps1"

# Network modules
. "$PSScriptRoot\network\Get-Interfaces.ps1"
. "$PSScriptRoot\network\Set-StaticIP.ps1"
. "$PSScriptRoot\network\Remove-StaticIP.ps1"

# NAT modules
. "$PSScriptRoot\nat\Get-NatStatus.ps1"
. "$PSScriptRoot\nat\New-NatRule.ps1"
. "$PSScriptRoot\nat\Remove-NatRule.ps1"

# Port Forward modules
. "$PSScriptRoot\portforward\New-PortForward.ps1"
. "$PSScriptRoot\portforward\Get-PortForward.ps1"
. "$PSScriptRoot\portforward\Remove-PortForward.ps1"

# Docker modules
. "$PSScriptRoot\docker\Get-DockerNetworks.ps1"
. "$PSScriptRoot\docker\New-DockerNat.ps1"

Export-ModuleMember -Function *
```

#### Alternative Auto-loading Approach

For more flexibility, you can use automatic loading:

```powershell
# Auto-load all .ps1 files recursively
Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 -Recurse |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function *
```

### IPv6 Guidelines

#### IPv6 Support Policy

**IPv6 is not supported** in WinRouter NAT operations. All NAT-related functionality is IPv4-only.

#### Rationale for IPv6 Exclusion

- **Compatibility Issues**: IPv6 support varies significantly between Windows versions
- **Common Failures**: "IPV6 sem suporte" errors are frequent on many systems
- **Limited Practical Use**: Most users only need IPv4 NAT functionality
- **Complexity Reduction**: Removing IPv6 simplifies code and reduces failure points

#### Development Guidelines

1. **NAT Functions**: All NAT-related functions must be IPv4-only
2. **No IPv6 Parameters**: Do not add IPv6-related parameters to NAT functions
3. **Error Handling**: Focus on system compatibility rather than IPv6 fallbacks
4. **Documentation**: Clearly state IPv6 is not supported in function help

#### Examples

**❌ DO NOT DO THIS:**

```powershell
function New-WinRouterNatRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$InternalIPInterfaceAddressPrefix,
        [switch]$IPv6Enabled  # IPv6 not supported
    )
}
```

**✅ DO THIS INSTEAD:**

```powershell
function New-WinRouterNatRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$InternalIPInterfaceAddressPrefix
    )
    # IPv4-only implementation
}
```

---

### NAT Naming Convention (Convencao de Nomes)

#### Padrao: `WR-NAT-{base}`

```powershell
# Exemplos:
#   192.168.50.0/24  → WR-NAT-50
#   192.168.60.0/24  → WR-NAT-60
#   192.168.70.0/24  → WR-NAT-70
```

**Por que `WR-NAT-{base}`:**

- Prefixo `WR-` identifica regra como propriedade do WinRouter
- Permite filtrar: `Where-Object { $_.Name -match '^WR-NAT-' }`
- Protege regras externas em fallback nuke

#### Funções Utilitárias

```powershell
# Gerar nome padrao
$natName = Get-NatRuleName -NetworkPrefix "192.168.60.0/24"
# Retorna: "WR-NAT-60"

# Verificar se regra e propria
Test-IsOwnedNatRule -NatName "WR-NAT-60"      # $true
Test-IsOwnedNatRule -NatName "NAT-Rede50"     # $false
```

#### Migracao de Regras Legadas

Regras com nomes antigos (`Rede60`, `NAT-Rede50-DESKTOP-*`) sao:

1. Detectadas pelo prefixo de rede
2. Reportadas como legadas no log
3. Substituidas pela nova convencao na proxima criacao

---

### NAT Implementation Guidelines (Método Validado WinNAT)

#### Pipeline Obrigatório (Ordem Imutável)

```powershell
# 1. WinNAT ativo antes de qualquer operacao NetNat
Set-Service -Name "WinNAT" -StartupType Automatic
Start-Service -Name "WinNAT"

# 2. Clean Slate - Remove TODAS as regras (sem filtro)
Get-NetNat | Remove-NetNat -Confirm:$false
Start-Sleep -Seconds 2

# 3. Criar nova regra (unica tentativa, sem retry)
New-NetNat -Name $Name -InternalIPInterfaceAddressPrefix $Prefix

# 4. Habilitar IP Forwarding (registro)
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
    -Name "IPEnableRouter" -Value 1
```

#### Regras Não Negociáveis

| #   | Regra                            | Justificativa                    |
| --- | -------------------------------- | -------------------------------- |
| 1   | Remoção total, sem filtro        | WinNAT suporta apenas 1 regra    |
| 2   | Sem SuccessLevel como gate       | Remove-NetNat é idempotente      |
| 3   | Sem retry loop em New-NetNat     | Falha = problema de estado do SO |
| 4   | Único caso especial: StopPending | Driver kernel travado → reboot   |
| 5   | Sleep pós-remoção ≤ 2s           | Mais que isso mascara erro real  |

#### Antipadrões (NUNCA IMPLEMENTAR)

**❌ Antipadrão 1: Remoção Filtrada por Prefixo**

```powershell
# NUNCA FAZER ISSO
Get-NetNat | Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $prefix } | Remove-NetNat
```

**❌ Antipadrão 2: SuccessLevel como Gate**

```powershell
# NUNCA FAZER ISSO
if ($removeResult.SuccessLevel -ne 'FULL') { throw "Remoção incompleta" }
```

**❌ Antipadrão 3: Retry Loop em New-NetNat**

```powershell
# NUNCA FAZER ISSO
for ($i = 1; $i -le 3; $i++) { try { New-NetNat ... } catch { Start-Sleep 3 } }
```

**❌ Antipadrão 4: Classificação de Erro IPv6**

```powershell
# NUNCA FAZER ISSO
if ($errMsg -match 'IPv6') { throw "Erro de IPv6: $errMsg" }
```

**❌ Antipadrão 5: Fallback com netsh Reset**

```powershell
# NUNCA FAZER ISSO
& netsh int ip reset
& netsh winsock reset
```

**❌ Antipadrão 6: Desabilitar WinNAT Permanentemente**

```powershell
# NUNCA FAZER ISSO
& sc.exe config winnat start= disabled
```

**❌ Antipadrão 7: Export-ModuleMember em Arquivos .ps1**

```powershell
# NUNCA FAZER ISSO em src/core/*.ps1 ou src/*/*.ps1
function Get-Exemplo { }
Export-ModuleMember -Function Get-Exemplo  # ❌ ERRO!
```

**Por que é errado:**

- `Export-ModuleMember` só funciona dentro de arquivos `.psm1`
- Arquivos `.ps1` no WinRouter são carregados via dot-sourcing
- Causa erro: "The Export-ModuleMember cmdlet can only be called from inside a module"

**Solução correta:**

- Remover `Export-ModuleMember` do arquivo `.ps1`
- Exportar funções no `WinRouter.psm1` via `Export-ModuleMember -Function *`

**Documentação:** [plans/module-loading-guidelines.md](plans/module-loading-guidelines.md)

#### Contrato das Funções NAT

**New-WinRouterNatRule:**

- **Input:** `Name` (string), `InternalIPInterfaceAddressPrefix` (string CIDR)
- **Output:** `$true` (sucesso) ou `throw` (falha)
- **Side Effects:** WinNAT ativo, todas regras anteriores removidas, nova regra criada
- **Proibido:** Configurar IPs, modificar rotas, alterar firewall

**Remove-WinRouterNatRule:**

- **Input:** `NatRule` (psobject)
- **Output:** void ou `throw` (apenas se StopPending)
- **Side Effects:** WinNAT ativo, todas regras removidas
- **Proibido:** Desabilitar serviço, chamar netsh reset, modificar registro

#### Checklist de Validação

Antes de commitar, verifique:

- [ ] `Get-NetNat` retorna 1 regra com prefixo correto e `Active=True`
- [ ] **NÃO** existe `Where-Object` filtrando regras na remoção
- [ ] **NÃO** existe loop retry em `New-NetNat`
- [ ] **NÃO** existe classificação de erro IPv6
- [ ] Único caso especial: `StopPending/not supported` → reboot
- [ ] Função **NÃO** configura IPs (sem `New-NetIPAddress`)
- [ ] `Start-Sleep` após remoção é ≤ 2 segundos
- [ ] **NÃO** desabilita WinNAT permanentemente
- [ ] **NÃO** chama `netsh reset`
- [ ] **NÃO** existe `Export-ModuleMember` em arquivos `.ps1` (apenas em `.psm1`)

### Module Organization Principles

#### 1. Single Responsibility Principle

Each `.ps1` file should contain functions related to a single domain:

- `Logger.ps1` - Logging functionality only
- `Get-Interfaces.ps1` - Interface analysis only
- `New-NatRule.ps1` - NAT rule creation only

#### 2. Function Naming Conventions

Use PowerShell's verb-noun convention:

- `Get-Interfaces` - Retrieve interface information
- `Set-StaticIP` - Configure static IP
- `New-NatRule` - Create new NAT rule
- `Remove-PortForward` - Remove port forwarding rule

#### 3. Module Dependencies

- Core modules (Logger, Elevation) should be loaded first
- Domain-specific modules can depend on core functionality
- Maintain clear dependency order in the `.psm1` file

### Module Loading Best Practices

#### 1. Error Handling

Always include error handling in module loading:

```powershell
try {
    . "$PSScriptRoot\core\Logger.ps1"
} catch {
    Write-Error "Failed to load Logger module: $($_.Exception.Message)"
    throw
}
```

#### 2. Path Resolution

Use `$PSScriptRoot` for reliable path resolution:

```powershell
# Correct - works regardless of current directory
. "$PSScriptRoot\core\Logger.ps1"

# Avoid - may fail if called from different directory
. "core\Logger.ps1"
```

#### 3. Function Export

Export only the functions you want to be publicly available:

```powershell
# Export all functions
Export-ModuleMember -Function *

# Export specific functions only
Export-ModuleMember -Function Get-Interfaces, Set-StaticIP

# Export functions and aliases
Export-ModuleMember -Function * -Alias *
```

#### 4. Export-ModuleMember — Regra Importante

**⚠️ NUNCA use `Export-ModuleMember` em arquivos `.ps1`**

```powershell
# ❌ NUNCA FAZER ISSO em src/core/*.ps1 ou src/*/*.ps1
function Get-Exemplo { }
Export-ModuleMember -Function Get-Exemplo  # ❌ ERRO!
```

**Motivo:** `Export-ModuleMember` só funciona dentro de arquivos `.psm1`. No WinRouter, os arquivos `.ps1` são carregados via dot-sourcing no `WinRouter.psm1`.

**Solução correta:**

```powershell
# ✅ CORRETO — src/core/Exemplo.ps1
function Get-Exemplo { }
# Sem Export-ModuleMember aqui

# ✅ CORRETO — src/WinRouter.psm1
. "$PSScriptRoot\core\Exemplo.ps1"
Export-ModuleMember -Function *  # Exporta no módulo principal
```

**Documentação completa:** [plans/module-loading-guidelines.md](plans/module-loading-guidelines.md)

### Development Workflow

#### Adding New Functionality

1. Create a new `.ps1` file in the appropriate subdirectory
2. Implement functions following naming conventions
3. Add dot-source line to `WinRouter.psm1`
4. Test the new functionality in isolation
5. Update documentation

#### Testing Individual Modules

Test modules in isolation by dot-sourcing directly:

```powershell
# Test Logger module independently
. "src\core\Logger.ps1"
Write-Log "Testing logger functionality"
```

#### Integration Testing

Test the complete module loading:

```powershell
Import-Module "src\WinRouter.psm1"
Get-Command -Module WinRouter  # Should list all exported functions
```

### Module Manifest (.psd1) - Future Considerations

While not required immediately, consider creating a module manifest for production use:

```powershell
# Create initial manifest
New-ModuleManifest -Path "src\WinRouter.psd1" `
    -RootModule "WinRouter.psm1" `
    -Author "Your Name" `
    -Description "Windows Router Configuration Module" `
    -ModuleVersion "1.0.0"
```

The manifest provides metadata about the module including version, author, dependencies, and exported functions.

### File Structure Summary

```
winrouter/
├── start-network.ps1          # Entry point with menu system
├── README.md                  # User documentation
│
├── src/
│   ├── WinRouter.psm1         # Main module orchestrator
│   ├── WinRouter.psd1         # Module manifest (optional)
│   │
│   ├── core/                  # Core functionality
│   │   ├── Logger.ps1         # Logging functions
│   │   └── Elevation.ps1      # Elevation and admin checks
│   │
│   ├── network/               # Network interface management
│   │   ├── Get-Interfaces.ps1
│   │   ├── Set-StaticIP.ps1
│   │   └── Remove-StaticIP.ps1
│   │
│   ├── nat/                   # NAT rule management
│   │   ├── Get-NatStatus.ps1
│   │   ├── New-NatRule.ps1
│   │   └── Remove-NatRule.ps1
│   │
│   ├── portforward/           # Port forwarding management
│   │   ├── New-PortForward.ps1
│   │   ├── Get-PortForward.ps1
│   │   └── Remove-PortForward.ps1
│   │
│   └── docker/                # Docker network integration
│       ├── Get-DockerNetworks.ps1
│       └── New-DockerNat.ps1
│
└── logs/                      # Runtime log files (in .gitignore)
```

This structure provides clear separation of concerns, making the codebase maintainable and extensible while following PowerShell best practices.
