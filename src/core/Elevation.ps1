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
