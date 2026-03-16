function Test-IsAdmin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (-not (Test-IsAdmin)) {
        $scriptPath = $MyInvocation.PSCommandPath
        
        # Fallback if PSCommandPath is empty (rare in script execution)
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            $scriptPath = $MyInvocation.MyCommand.Definition
        }

        Write-Host "Elevating privileges for: $scriptPath" -ForegroundColor Yellow
        
        $exe = if ($IsCoreCLR) { "pwsh.exe" } else { "powershell.exe" }
        
        Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}

function Get-IPForwardingStatus {
    $val = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -ErrorAction SilentlyContinue).IPEnableRouter
    if ($val -eq 1) { return $true }
    return $false
}

function Enable-IPForwarding {
    Write-Host "Enabling IP Forwarding (Registry)..." -ForegroundColor Cyan
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -Value 1 -Type DWord
    Write-Host "IP Forwarding enabled." -ForegroundColor Green
}
