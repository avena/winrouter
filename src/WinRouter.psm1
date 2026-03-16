# WinRouter.psm1
# PowerShell Module Orchestrator
#
# This module serves as the central orchestrator for the WinRouter project.
# It dot-sources all component modules and exports their functions for use.
#
# Usage: Import-Module "src\WinRouter.psm1"

# Core modules - loaded first as they provide essential functionality
try {
  Write-Verbose "Loading core modules..."

  # Logger module - provides centralized logging
  . "$PSScriptRoot\core\Logger.ps1"
  Write-Verbose "✓ Logger module loaded"

  # Elevation module - handles privilege escalation
  . "$PSScriptRoot\core\Elevation.ps1"
  Write-Verbose "✓ Elevation module loaded"

  # Utils module - NAT naming conventions and helpers
  . "$PSScriptRoot\core\Utils.ps1"
  Write-Verbose "✓ Utils module loaded"

}
catch {
  Write-Error "Failed to load core modules: $($_.Exception.Message)"
  throw
}

# Network modules
try {
  Write-Verbose "Loading network modules..."

  # Network interface management
  . "$PSScriptRoot\network\Get-Interfaces.ps1"
  Write-Verbose "✓ Get-Interfaces module loaded"

  . "$PSScriptRoot\network\Set-StaticIP.ps1"
  Write-Verbose "✓ Set-StaticIP module loaded"

  . "$PSScriptRoot\network\Remove-StaticIP.ps1"
  Write-Verbose "✓ Remove-StaticIP module loaded"

}
catch {
  Write-Error "Failed to load network modules: $($_.Exception.Message)"
  throw
}

# NAT modules
try {
  Write-Verbose "Loading NAT modules..."

  # NAT status and management
  . "$PSScriptRoot\nat\Get-NatStatus.ps1"
  Write-Verbose "✓ Get-NatStatus module loaded"

  . "$PSScriptRoot\nat\New-NatRule.ps1"
  Write-Verbose "✓ New-NatRule module loaded"

  . "$PSScriptRoot\nat\Remove-NatRule.ps1"
  Write-Verbose "✓ Remove-NatRule module loaded"

}
catch {
  Write-Error "Failed to load NAT modules: $($_.Exception.Message)"
  throw
}

# Export all functions for use
Write-Verbose "Exporting all functions..."
Export-ModuleMember -Function *

# Module metadata
$script:ModuleVersion = "1.0.0"
$script:ModuleAuthor = "WinRouter Team"
$script:ModuleDescription = "Windows Router Configuration Module"

Write-Verbose "WinRouter module loaded successfully"
Write-Verbose "Version: $ModuleVersion"
Write-Verbose "Author: $ModuleAuthor"
