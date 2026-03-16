# WinRouter Development Guide

## Overview

This document provides comprehensive guidelines for developers working on the WinRouter project. It covers coding standards, module development, testing procedures, and contribution guidelines.

## Development Environment Setup

### Prerequisites

- **PowerShell 5.1+** or **PowerShell 7+**
- **Windows 10/11** (required for network functionality)
- **Git** for version control
- **Visual Studio Code** (recommended) with PowerShell extension

### Recommended Tools

- **PowerShell Extension for VS Code**: Provides syntax highlighting and debugging
- **PSScriptAnalyzer**: PowerShell code analysis tool
- **Pester**: PowerShell testing framework
- **PowerShell Universal**: For web-based management interface (optional)

## Module Development

### Creating New Modules

#### 1. Module Structure

Each module should follow this structure:

```powershell
# Module Header
<#
.SYNOPSIS
Brief description of the module's purpose

.DESCRIPTION
Detailed description of what the module does

.EXAMPLE
Example usage of the module

.NOTES
Additional notes, author information, version history
#>

# Module Functions
function Get-ExampleData {
    <#
    .SYNOPSIS
    Brief description of the function

    .DESCRIPTION
    Detailed description of what the function does

    .PARAMETER ParameterName
    Description of the parameter

    .EXAMPLE
    Example usage of the function

    .OUTPUTS
    Description of what the function returns

    .NOTES
    Additional notes
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ParameterName
    )

    try {
        # Function implementation
        Write-Log "Processing parameter: $ParameterName"

        # Return result
        return $result
    } catch {
        Write-Error "Failed to process parameter: $($_.Exception.Message)"
        throw
    }
}

# Export functions
Export-ModuleMember -Function Get-ExampleData
```

#### 2. Function Naming Convention

Use PowerShell's verb-noun convention:

- **Get-**: Retrieve data (e.g., `Get-Interfaces`, `Get-NatStatus`)
- **Set-**: Modify configuration (e.g., `Set-StaticIP`, `Set-NatRule`)
- **New-**: Create new resources (e.g., `New-NatRule`, `New-PortForward`)
- **Remove-**: Delete resources (e.g., `Remove-StaticIP`, `Remove-NatRule`)
- **Test-**: Validate conditions (e.g., `Test-Admin`, `Test-PortAvailability`)
- **Start-**: Begin operations (e.g., `Start-Elevated`, `Start-NetworkService`)
- **Stop-**: End operations (e.g., `Stop-NetworkService`)

#### 3. Parameter Validation

Always validate parameters:

```powershell
function Set-StaticIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$InterfaceName,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
        [string]$IPAddress,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
        [string]$SubnetMask,

        [Parameter()]
        [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
        [string]$DefaultGateway
    )

    # Function implementation
}
```

### Module Integration

#### 1. Adding to Main Module

Add your new module to `src/WinRouter.psm1`:

```powershell
# Add your module loading
. "$PSScriptRoot\yourmodule\YourModule.ps1"

# Or use auto-loading for all modules in a directory
Get-ChildItem -Path "$PSScriptRoot\yourmodule" -Filter *.ps1 -Recurse |
    ForEach-Object { . $_.FullName }
```

#### 2. Function Export

Ensure your functions are exported:

```powershell
# Export specific functions
Export-ModuleMember -Function Get-YourFunction, Set-YourFunction

# Or export all functions (if using auto-loading)
Export-ModuleMember -Function *
```

## Testing

### Unit Testing with Pester

Create test files alongside your modules:

```powershell
# src/core/Logger.Tests.ps1
Describe "Logger Module" {
    BeforeAll {
        # Import the module
        . "$PSScriptRoot\Logger.ps1"
    }

    Context "Write-Log Function" {
        It "Should write log entry with timestamp" {
            # Test implementation
            $result = Write-Log "Test message"
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle different log levels" {
            # Test different log levels
            { Write-Log "Info message" -Level "INFO" } | Should -Not -Throw
            { Write-Log "Error message" -Level "ERROR" } | Should -Not -Throw
        }
    }
}
```

### Integration Testing

Test module loading and function availability:

```powershell
Describe "WinRouter Module Integration" {
    BeforeAll {
        # Import the main module
        Import-Module "$PSScriptRoot\WinRouter.psm1" -Force
    }

    It "Should load all expected functions" {
        $expectedFunctions = @(
            "Get-Interfaces",
            "Set-StaticIP",
            "Get-NatStatus",
            "New-NatRule",
            "New-PortForward"
        )

        foreach ($function in $expectedFunctions) {
            (Get-Command $function -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }
}
```

### Manual Testing

#### 1. Individual Module Testing

```powershell
# Test a specific module
. "src\core\Logger.ps1"
Write-Log "Testing logger functionality"
```

#### 2. Full Module Testing

```powershell
# Test complete module loading
Import-Module "src\WinRouter.psm1"
Get-Command -Module WinRouter | Format-Table -AutoSize
```

## Code Quality

### PSScriptAnalyzer Rules

Configure PSScriptAnalyzer in `.vscode/settings.json`:

```json
{
  "powershell.scriptAnalysis.enable": true,
  "powershell.scriptAnalysis.settingsPath": "./.vscode/PSScriptAnalyzerSettings.psd1"
}
```

Create `.vscode/PSScriptAnalyzerSettings.psd1`:

```powershell
@{
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSUseApprovedVerbs',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSAvoidUsingCmdletAliases',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSUseCorrectCasing'
    )
    ExcludeRules = @(
        'PSUseToExportFieldsInManifest'
    )
}
```

### Code Review Checklist

Before submitting changes:

- [ ] All functions have proper help documentation
- [ ] Parameters are validated appropriately
- [ ] Error handling is implemented
- [ ] Functions follow naming conventions
- [ ] Code passes PSScriptAnalyzer rules
- [ ] Unit tests are written and passing
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] No breaking changes to existing API

## Debugging

### Debug Mode

Enable debug mode for detailed logging:

```powershell
$env:WINROUTER_DEBUG = $true
.\start-network.ps1
```

### Common Debugging Techniques

#### 1. Verbose Output

```powershell
# Enable verbose output
$VerbosePreference = 'Continue'
Import-Module "src\WinRouter.psm1"
```

#### 2. Breakpoints

```powershell
# Set breakpoints in VS Code or PowerShell
Set-PSBreakpoint -Command Get-Interfaces
```

#### 3. Step-through Debugging

```powershell
# Use VS Code debugger or PowerShell ISE
Import-Module "src\WinRouter.psm1" -Force
```

### Troubleshooting Common Issues

#### Module Loading Failures

```powershell
# Check module loading
$ErrorActionPreference = 'Stop'
try {
    Import-Module "src\WinRouter.psm1"
    Write-Host "Module loaded successfully"
} catch {
    Write-Error "Module loading failed: $($_.Exception.Message)"
    # Check individual module loading
    Get-ChildItem "src" -Filter *.ps1 -Recurse | ForEach-Object {
        try {
            . $_.FullName
            Write-Host "Loaded: $($_.Name)"
        } catch {
            Write-Error "Failed to load $($_.Name): $($_.Exception.Message)"
        }
    }
}
```

#### Function Not Found

```powershell
# Check if function is exported
Get-Command -Module WinRouter | Where-Object { $_.Name -like "*YourFunction*" }

# Check module exports
(Get-Module WinRouter).ExportedFunctions
```

## Performance Optimization

### Module Loading Optimization

1. **Lazy Loading**: Load modules only when needed
2. **Caching**: Cache frequently accessed data
3. **Async Operations**: Use background jobs for long-running operations

### Memory Management

```powershell
# Clear variables after use
Remove-Variable -Name $variable -ErrorAction SilentlyContinue

# Force garbage collection (if needed)
[System.GC]::Collect()
```

### Network Operation Optimization

```powershell
# Use parallel processing for multiple network operations
$interfaces = Get-NetAdapter | ForEach-Object -Parallel {
    # Process each interface in parallel
    Get-NetIPConfiguration -InterfaceAlias $_.Name
}
```

## Security Best Practices

### Input Validation

Always validate user inputs:

```powershell
function Validate-IPAddress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )

    if (-not ($IPAddress -match '^(\d{1,3}\.){3}\d{1,3}$')) {
        throw "Invalid IP address format: $IPAddress"
    }

    $octets = $IPAddress -split '\.'
    foreach ($octet in $octets) {
        if ([int]$octet -lt 0 -or [int]$octet -gt 255) {
            throw "Invalid IP address octet: $octet"
        }
    }
}
```

### Privilege Management

```powershell
function Test-Admin {
    <#
    .SYNOPSIS
    Test if current session has administrator privileges

    .RETURNS
    [bool] True if running as administrator
    #>

    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-Error "Failed to check administrator privileges: $($_.Exception.Message)"
        return $false
    }
}
```

### Logging Security

```powershell
function Write-SecureLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    # Sanitize message to prevent log injection
    $sanitizedMessage = $Message -replace '[\r\n]', ' '

    # Write to secure log location
    $logPath = Join-Path $env:ProgramData "WinRouter\secure.log"
    Add-Content -Path $logPath -Value "[$(Get-Date)] [$Level] $sanitizedMessage"
}
```

## Version Control

### Git Workflow

Follow the GitFlow strategy outlined in `plans/gitflow.md`:

1. **Feature Branches**: Create from `refactor/modular-structure`
2. **Commit Messages**: Use conventional commit format
3. **Pull Requests**: Required for all changes
4. **Code Review**: Mandatory before merging

### Commit Message Format

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Example:**

```
feat(network): Add support for IPv6 configuration

- Implement Get-IPv6Addresses function
- Add Set-IPv6Address function
- Update interface analysis to include IPv6

Closes #123
```

## Continuous Integration

### Automated Testing

Set up CI pipeline to run:

1. **PSScriptAnalyzer**: Code quality checks
2. **Pester Tests**: Unit and integration tests
3. **Module Loading Tests**: Verify all modules load correctly
4. **Backward Compatibility**: Ensure no breaking changes

### Build Process

```powershell
# Build script example
$ErrorActionPreference = 'Stop'

Write-Host "Running PSScriptAnalyzer..."
Invoke-ScriptAnalyzer -Path "src\" -Settings ".vscode/PSScriptAnalyzerSettings.psd1"

Write-Host "Running Pester tests..."
Invoke-Pester -Path "tests\" -Output Detailed

Write-Host "Testing module loading..."
Import-Module "src\WinRouter.psm1" -Force
Get-Command -Module WinRouter | Out-Null

Write-Host "Build completed successfully!"
```

This development guide provides comprehensive information for contributing to the WinRouter project. Always refer to the latest version of this document and the project's main documentation for the most up-to-date guidelines.
