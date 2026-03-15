# MVP Plan: Interface Discovery & Selection

This plan outlines the steps to extract the essential network interface discovery and user selection logic from the legacy scripts into the new modular structure. This creates the foundation for the WinRouter project.

## Objective
Create a minimal working runtime that:
1.  Checks for Administrator privileges.
2.  Discovers available network interfaces.
3.  Displays them in a clear, formatted table.
4.  Allows the user to select WAN (Internet) and LAN (Internal) interfaces.

## Source Code Analysis
The core logic is derived primarily from `old-base-script/config-nat-multi.ps1`.

### 1. Admin Privilege Check
*   **Source:** `config-nat-multi.ps1` (Lines 18-30)
*   **Logic:** Checks `[Security.Principal.WindowsPrincipal]` for the Administrator role. Relaunches with `-Verb RunAs` if false.
*   **Target:** `src/core/Elevation.ps1`

### 2. Interface Discovery
*   **Source:** `config-nat-multi.ps1` (Lines 77-108)
*   **Logic:**
    *   `Get-NetAdapter`: Filters for 'Up' or 'Disconnected'.
    *   `Get-NetIPAddress`: Retrieves IPv4 addresses for each adapter.
    *   **Gateway Detection:** Identifies if an interface already acts as a gateway (ends in `.1` in private ranges).
    *   **NAT Association:** Checks if `Get-NetNat` rules match the interface's subnet.
*   **Target:** `src/network/Get-Interfaces.ps1`
    *   *Function:* `Get-WinRouterInterfaces`
    *   *Output:* Returns a list of PSCustomObjects containing: `{ Letra, Name, InterfaceIndex, IP, Status, GatewayStatus }`.
    *   *Improvement:* Assign a "Selection Letter" (A, B, C...) dynamically to simplify user input.

### 3. User Selection Interface
*   **Source:** `config-nat-multi.ps1` (Lines 153-166)
*   **Logic:**
    *   Displays the list using `Format-Table`.
    *   Prompts for **WAN** interface using the Selection Letter.
    *   Prompts for **LAN** interface(s) using Selection Letter(s).
    *   Validates that WAN and LAN are not the same and are valid selections.
*   **Target:** `start-network.ps1` (Entry Point)

## Implementation Steps

### Step 1: Core Essentials
Create `src/core/Elevation.ps1` to handle the admin check.

### Step 2: Interface Module
Create `src/network/Get-Interfaces.ps1`.
```powershell
function Get-WinRouterInterfaces {
    # Logic to fetch adapters, map IPs, and assign selection IDs (A, B, C...)
    # Returns object collection
}
```

### Step 3: Entry Point (MVP)
Create/Update `start-network.ps1` to:
1.  Dot-source `src/core/Elevation.ps1` and call `Test-Admin`.
2.  Dot-source `src/network/Get-Interfaces.ps1`.
3.  Call `Get-WinRouterInterfaces` and store results.
4.  Print the table.
5.  Implement `Read-Host` logic to capture user choices.
6.  **Verification Output:** Write-Host the selected WAN and LAN details to confirm logic works.

## Verification
Run `.\start-network.ps1`.
*   [ ] Script requests Admin rights (if not present).
*   [ ] Table lists all network adapters correctly.
*   [ ] Selecting 'A' (or relevant letter) correctly identifies the WAN object.
*   [ ] Selecting 'B' (or relevant letter) correctly identifies the LAN object.
