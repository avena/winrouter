# Test script for Logger enhancements
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\src\core\Logger.ps1"

Write-Section "Testing Logger Enhancements"
Write-Step -Step 1 -Total 3 -Message "Initializing..."

$testObj = [PSCustomObject]@{ Name = "Test"; ID = 123; Status = "Active" }
Write-LogObject -InputObject $testObj -Message "Test Object"

Write-Step -Step 2 -Total 3 -Message "Processing..."
Write-Step -Step 3 -Total 3 -Message "Done."
Write-Log "Logger test complete." -Level 'SUCCESS'
