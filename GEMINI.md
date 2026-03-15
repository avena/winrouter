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
