# WinRouter FAQ

## General Questions

### What is WinRouter?

WinRouter is a PowerShell-based Windows router configuration tool that simplifies network setup, NAT configuration, port forwarding, and Docker network integration. It provides an interactive menu system and modular architecture for easy maintenance and extensibility.

### What are the system requirements?

- **Operating System**: Windows 10 or Windows 11
- **PowerShell**: Version 5.1 or later (PowerShell 7+ recommended)
- **Privileges**: Administrator rights required for network configuration
- **Optional**: Docker Desktop for Docker network integration

### Is WinRouter safe to use?

Yes, WinRouter follows security best practices:

- All network operations require administrator privileges
- Input validation is performed on all user inputs
- Sensitive operations are logged for audit purposes
- No external network connections are made without user consent

### Can I use WinRouter in a production environment?

WinRouter is suitable for production use, but we recommend:

- Testing in a development environment first
- Backing up your current network configuration
- Understanding the changes being made
- Having a rollback plan in case of issues

## Installation and Setup

### How do I install WinRouter?

1. Clone or download the repository
2. Ensure you have PowerShell 5.1+ installed
3. Run `.\start-network.ps1` from an elevated PowerShell session
4. The script will automatically handle module loading and setup

### Do I need to install any dependencies?

No additional dependencies are required. WinRouter uses built-in Windows PowerShell modules and cmdlets. Optional dependencies include:

- Docker Desktop (for Docker integration features)
- PSScriptAnalyzer (for development and code quality)

### Why does WinRouter need administrator privileges?

Network configuration operations require elevated privileges:

- Creating and modifying NAT rules
- Configuring IP addresses and routing
- Managing firewall rules
- Accessing system network information

## Usage Questions

### How do I run WinRouter?

```powershell
# From the project directory
.\start-network.ps1
```

The script will automatically elevate to administrator if needed and present the main menu.

### What does the main menu offer?

The main menu provides access to:

1. **Network Interface Management**: View, configure, and manage network interfaces
2. **NAT Configuration**: Create, view, and remove NAT rules
3. **Port Forwarding**: Set up port forwarding rules for external access
4. **Docker Integration**: Configure NAT for Docker networks
5. **System Information**: View network status and configuration

### How do I configure a static IP address?

1. From the main menu, select "Network Interface Management"
2. Choose "Configure Static IP"
3. Select the network interface
4. Enter the IP address, subnet mask, and gateway
5. Confirm the changes

### How do I set up port forwarding?

1. From the main menu, select "Port Forwarding"
2. Choose "Add Port Forwarding Rule"
3. Specify the external port, internal IP, and internal port
4. Confirm the rule creation

### Can I use WinRouter with Docker?

Yes! WinRouter includes Docker integration:

1. Ensure Docker Desktop is installed and running
2. From the main menu, select "Docker Integration"
3. View available Docker networks
4. Configure NAT rules for Docker bridge networks

## Troubleshooting

### WinRouter won't start or gives permission errors

**Solution**: Run PowerShell as Administrator:

- Right-click PowerShell and select "Run as administrator"
- Or use the built-in elevation function in the script

### Module loading fails

**Common causes and solutions**:

- **Missing files**: Verify all `.ps1` files exist in the `src/` directory
- **Syntax errors**: Check individual module files for PowerShell syntax errors
- **Path issues**: Ensure you're running from the correct directory

### Network configuration doesn't work

**Troubleshooting steps**:

1. Verify administrator privileges
2. Check if the network interface is enabled
3. Ensure IP addresses are not already in use
4. Verify no conflicting routes exist
5. Check firewall settings

### NAT rules aren't working

**Common issues**:

- IP forwarding not enabled (WinRouter should handle this automatically)
- Conflicting NAT rules from other applications
- Firewall blocking traffic
- Incorrect external IP address configuration

### Port forwarding isn't accessible

**Check these items**:

- Port is not already in use by another service
- Firewall allows the port
- NAT rule is correctly configured
- External IP address is correct
- Router (if present) forwards to the Windows machine

## Advanced Questions

### Can I use WinRouter programmatically?

Yes, you can use individual functions:

```powershell
# Import the module
Import-Module "src\WinRouter.psm1"

# Use individual functions
Get-Interfaces
New-NatRule -Name "MyNAT" -InternalIPInterfaceAddressPrefix "192.168.1.0/24"
New-PortForward -ExternalPort 8080 -InternalIP "192.168.1.100" -InternalPort 80
```

### How do I add custom functionality?

1. Create a new `.ps1` file in the appropriate subdirectory
2. Follow the existing function naming conventions
3. Add dot-source line to `WinRouter.psm1`
4. Test the new functionality
5. Update documentation

### Can I customize the logging?

Yes, logging is configurable:

- Set `$env:WINROUTER_DEBUG = $true` for debug mode
- Logs are written to the `logs/` directory
- Different log levels are supported (INFO, WARN, ERROR)

### How does WinRouter handle errors?

WinRouter includes comprehensive error handling:

- Input validation on all user inputs
- Try-catch blocks for all operations
- Detailed error messages with troubleshooting suggestions
- Logging of all operations and errors

## Development Questions

### How is WinRouter structured?

WinRouter uses a modular PowerShell architecture:

- **Main Module** (`WinRouter.psm1`): Orchestrates all functionality
- **Core Modules**: Logging, elevation, and utility functions
- **Domain Modules**: Network, NAT, port forwarding, and Docker functions
- **Entry Point** (`start-network.ps1`): Main script with menu system

### What coding standards does WinRouter follow?

- PowerShell verb-noun naming convention
- Comprehensive help documentation for all functions
- Input validation and error handling
- Consistent code formatting and indentation
- Modular design with single responsibility principle

### How do I contribute to WinRouter?

1. Fork the repository
2. Create a feature branch
3. Follow the development guidelines in `docs/DEVELOPMENT.md`
4. Write tests for new functionality
5. Update documentation
6. Submit a pull request

### What testing is required?

- Unit tests using Pester framework
- Integration testing for module loading
- Manual testing of new functionality
- Verification of backward compatibility

## Performance and Security

### Is WinRouter secure?

Yes, WinRouter implements several security measures:

- All network operations require administrator privileges
- Input validation prevents injection attacks
- Sensitive operations are logged for audit trails
- No external network connections without user consent
- Docker integration follows Docker security best practices

### How does WinRouter perform?

WinRouter is optimized for performance:

- Lazy loading of modules when needed
- Efficient network operations
- Minimal memory footprint
- Fast startup times
- Asynchronous operations for long-running tasks

### Can WinRouter handle high-traffic scenarios?

WinRouter is designed for configuration management, not high-traffic routing:

- It configures Windows built-in NAT and routing
- Performance depends on Windows network stack
- Suitable for typical home and small business use cases
- For high-traffic scenarios, consider dedicated routing hardware

## Integration and Compatibility

### Does WinRouter work with other networking software?

Generally yes, but be aware of:

- **Conflicts**: Other NAT or firewall software might conflict
- **Compatibility**: Most Windows networking tools work alongside WinRouter
- **Priority**: Windows processes rules in a specific order

### Can I use WinRouter with virtual machines?

Yes, WinRouter works with virtual machines:

- Can configure NAT for VM networks
- Works with Hyper-V, VMware, VirtualBox
- Can set up port forwarding to VMs
- Supports bridged and NAT network modes

### Is WinRouter compatible with different Windows versions?

WinRouter supports:

- **Windows 10** (all versions)
- **Windows 11** (all versions)
- **PowerShell 5.1+** (built-in)
- **PowerShell 7+** (recommended for latest features)

## Support and Maintenance

### Where can I get help?

- **Documentation**: Check the `docs/` directory for comprehensive guides
- **Issues**: Report problems on the project's GitHub repository
- **Troubleshooting**: Use the troubleshooting guide in `docs/TROUBLESHOOTING.md`
- **Community**: Join discussions for tips and support

### How often is WinRouter updated?

Updates depend on:

- Bug fixes and security patches
- New Windows features and PowerShell capabilities
- User feedback and feature requests
- Compatibility with new Windows versions

### How do I backup my WinRouter configuration?

WinRouter configurations are Windows network settings:

- Use Windows System Restore before major changes
- Document your network topology
- Keep notes on custom configurations
- Test rollback procedures in a safe environment

### Can I automate WinRouter operations?

Yes, through several methods:

- **PowerShell scripts**: Use individual functions programmatically
- **Scheduled tasks**: Run specific operations on a schedule
- **Integration**: Call WinRouter functions from other scripts
- **API**: Future versions may include REST API support

## Licensing and Legal

### What license is WinRouter under?

WinRouter is licensed under the MIT License, which allows:

- Free use for personal and commercial purposes
- Modification and distribution
- No warranty or liability
- Attribution required in derivative works

### Are there any restrictions on use?

The MIT License is very permissive:

- No restrictions on commercial use
- No restrictions on modification
- No restrictions on distribution
- Only requirement is attribution in derivative works

### Is WinRouter open source?

Yes, WinRouter is fully open source:

- Source code is publicly available
- Community contributions are welcome
- Transparent development process
- No hidden functionality or backdoors

This FAQ covers the most common questions about WinRouter. For more detailed information, please refer to the specific documentation files in the `docs/` directory.
