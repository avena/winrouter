# WinRouter Documentation

## Overview

WinRouter is a PowerShell-based Windows router configuration tool designed to simplify network setup, NAT configuration, port forwarding, and Docker network integration. This project has been refactored into a modular structure for better maintainability and extensibility.

## Project Structure

```
winrouter/
├── start-network.ps1          # Main entry point with menu system
├── README.md                  # User documentation
├── GEMINI.md                  # Development guidelines and PowerShell module standards
├── plans/                     # Project planning documents
│   ├── plan.md               # Modularization roadmap
│   └── gitflow.md            # Git workflow strategy
│
├── src/                       # Source code modules
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
├── logs/                      # Runtime log files (auto-generated)
└── old-base-script/           # Legacy scripts (for reference)
```

## Quick Start

### Prerequisites

- Windows 10/11 with PowerShell 5.1 or later
- Administrator privileges (required for network configuration)
- Docker Desktop (optional, for Docker network integration)

### Installation

1. Clone the repository:

   ```powershell
   git clone <repository-url>
   cd winrouter
   ```

2. Run the main script:

   ```powershell
   .\start-network.ps1
   ```

   The script will automatically elevate to administrator privileges if needed.

### Usage

The main script provides an interactive menu system:

```
WinRouter - Windows Router Configuration Tool
============================================

1. Network Interface Management
   - View available interfaces
   - Configure static IP addresses
   - Remove IP configurations

2. NAT Configuration
   - View current NAT rules
   - Create new NAT rules
   - Remove existing NAT rules

3. Port Forwarding
   - View port forwarding rules
   - Add new port forwarding rules
   - Remove port forwarding rules

4. Docker Integration
   - View Docker networks
   - Configure NAT for Docker networks

5. System Information
   - View system network status
   - Check IP forwarding status

0. Exit
```

## Module Architecture

### PowerShell Module (.psm1) Structure

The project uses a multi-file PowerShell module approach where:

- **WinRouter.psm1**: Main module orchestrator that dot-sources all component modules
- **Individual .ps1 files**: Each contains functions for a specific domain
- **Automatic loading**: All modules are automatically loaded when the main module is imported

### Core Modules

#### Logger Module (`src/core/Logger.ps1`)

Provides centralized logging functionality:

- `Write-Log`: Standard logging with timestamps
- `Write-LogCmd`: Command execution logging

#### Elevation Module (`src/core/Elevation.ps1`)

Handles privilege escalation:

- `Test-Admin`: Check if running as administrator
- `Start-Elevated`: Self-elevation to administrator

### Network Modules

#### Interface Management (`src/network/`)

- `Get-Interfaces`: List and analyze network interfaces
- `Set-StaticIP`: Configure static IP addresses
- `Remove-StaticIP`: Remove IP configurations

#### NAT Management (`src/nat/`)

- `Get-NatStatus`: View NAT rules and IP forwarding status
- `New-NatRule`: Create new NAT rules
- `Remove-NatRule`: Remove NAT rules

#### Port Forwarding (`src/portforward/`)

- `New-PortForward`: Add portproxy rules
- `Get-PortForward`: List portproxy rules
- `Remove-PortForward`: Remove portproxy rules

### Docker Integration (`src/docker/`)

#### Docker Network Management

- `Get-DockerNetworks`: List Docker bridge networks
- `New-DockerNat`: Configure NAT for Docker networks

## Development Guidelines

### Adding New Functionality

1. **Create Module File**: Add a new `.ps1` file in the appropriate subdirectory
2. **Follow Naming Convention**: Use PowerShell verb-noun convention (e.g., `Get-Data`, `Set-Config`)
3. **Single Responsibility**: Each file should handle one specific domain
4. **Update Main Module**: Add dot-source line to `WinRouter.psm1`
5. **Test Individually**: Test the new module in isolation
6. **Update Documentation**: Add to this README and GEMINI.md

### Testing

#### Individual Module Testing

```powershell
# Test a specific module
. "src\core\Logger.ps1"
Write-Log "Testing logger functionality"
```

#### Integration Testing

```powershell
# Test complete module loading
Import-Module "src\WinRouter.psm1"
Get-Command -Module WinRouter  # Should list all exported functions
```

### Error Handling

All modules should include proper error handling:

```powershell
try {
    # Module loading
    . "$PSScriptRoot\core\Logger.ps1"
} catch {
    Write-Error "Failed to load Logger module: $($_.Exception.Message)"
    throw
}
```

## Troubleshooting

### Common Issues

#### Permission Errors

- Ensure you're running PowerShell as Administrator
- Check UAC settings if elevation fails

#### Module Loading Errors

- Verify all `.ps1` files exist in their expected locations
- Check for syntax errors in individual modules
- Ensure proper path resolution using `$PSScriptRoot`

#### Network Configuration Issues

- Verify network adapter names are correct
- Check if IP addresses are already in use
- Ensure no conflicting NAT rules exist

### Log Files

All operations are logged to the `logs/` directory:

- `winrouter.log`: Main application log
- `network.log`: Network-specific operations
- `nat.log`: NAT rule operations
- `docker.log`: Docker integration operations

### Debug Mode

Enable debug mode by setting the environment variable:

```powershell
$env:WINROUTER_DEBUG = $true
.\start-network.ps1
```

## Contributing

### Code Style

- Use PowerShell verb-noun naming convention
- Follow the existing module structure
- Include proper error handling
- Add comprehensive comments for complex functions
- Use consistent indentation (4 spaces)

### Git Workflow

1. Create feature branch from `refactor/modular-structure`
2. Implement changes following the modular structure
3. Test thoroughly before committing
4. Create pull request with detailed description
5. Follow the GitFlow strategy outlined in `plans/gitflow.md`

### Testing Requirements

- All new modules must be tested individually
- Integration testing required for module loading
- Verify backward compatibility with original script
- Test on different Windows versions when possible

## Security Considerations

- All network configuration requires administrator privileges
- Input validation is performed on all user inputs
- Sensitive operations are logged for audit purposes
- Docker integration follows Docker security best practices

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Support

For issues, questions, or contributions:

1. Check the existing issues and documentation
2. Create a new issue with detailed information
3. Include relevant log files when reporting problems
4. Provide your Windows version and PowerShell version

## Version History

### v1.0.0

- Initial modular refactoring
- PowerShell module structure implementation
- Core functionality preservation
- Documentation updates

## Dependencies

- **PowerShell 5.1+**: Required for all functionality
- **Windows Admin Center**: Optional for GUI management
- **Docker Desktop**: Optional for Docker network integration
- **Windows Admin Tools**: Required for NAT and port forwarding

## Performance Notes

- Module loading is optimized for fast startup
- Network operations are performed asynchronously when possible
- Logging is configurable to reduce overhead
- Memory usage is monitored and optimized

For more detailed technical information, see the `GEMINI.md` file and the individual module documentation.
