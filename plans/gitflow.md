# GitFlow Strategy for WinRouter Refactoring

This document outlines the branching strategy for refactoring the WinRouter project from a single script (`config-nat-multi.ps1`) to a modular structure.

## Branch Structure

The strategy uses a **tree-like branch model**:

```
main                          ← original script (config-nat-multi.ps1) - stable
└── refactor/modular-structure  ← integration branch for the full refactoring
    ├── refactor/core           ← Tasks 3 (Logger + Elevation)
    ├── refactor/network        ← Task 4 (Get-Interfaces, Set/Remove-StaticIP)
    ├── refactor/nat            ← Task 5 (Get-NatStatus, New/Remove-NatRule)
    ├── refactor/portforward    ← Task 6 (New/Get/Remove-PortForward)
    ├── refactor/docker         ← Task 7 (Get-DockerNetworks, New-DockerNat)
    └── refactor/entrypoint     ← Task 8 (start-network.ps1 + WinRouter.psm1)
```

## Step-by-Step Instructions

### 1. Create the integration branch from `main`

```bash
git checkout main
git checkout -b refactor/modular-structure
# Create the directory structure (with .gitkeep files)
mkdir -p src/{core,network,nat,portforward,docker} logs
New-Item src/WinRouter.psm1, logs/.gitkeep
git add .
git commit -m "refactor: scaffold directory structure for modularization"
git push -u origin refactor/modular-structure
```

### 2. For each module group, create a branch from the integration branch

```bash
# Example: core branch
git checkout refactor/modular-structure
git checkout -b refactor/core

# Implement Logger.ps1 and Elevation.ps1
git add src/core/
git commit -m "refactor: add Logger.ps1 with Write-Log and Write-LogCmd"
git commit -m "refactor: add Elevation.ps1 with self-elevation logic"
git push -u origin refactor/core

# Merge back into the integration branch
git checkout refactor/modular-structure
git merge --no-ff refactor/core -m "merge: core module (Logger + Elevation)"
```

### 3. Dependency Order Between Branches

Follow this sequence to avoid conflicts:

| Order | Branch                 | Depends On                |
| ----- | ---------------------- | ------------------------- |
| 1st   | `refactor/core`        | none                      |
| 2nd   | `refactor/network`     | `core` (uses `Write-Log`) |
| 3rd   | `refactor/nat`         | `core` + `network`        |
| 4th   | `refactor/portforward` | `core`                    |
| 5th   | `refactor/docker`      | `core` + `nat`            |
| 6th   | `refactor/entrypoint`  | all above                 |

### 4. Rebase to Keep History Clean

If the integration branch advances while you're working on a sub-branch:

```bash
git checkout refactor/nat
git rebase refactor/modular-structure
# Resolve conflicts, then:
git checkout refactor/modular-structure
git merge --no-ff refactor/nat
```

### 5. Final Merge to `main` After Validation

```bash
git checkout main
git merge --no-ff refactor/modular-structure -m "refactor: modularize WinRouter into src/ structure"
git tag -a v2.0.0 -m "Modular structure with src/ layout"
```

## Commit Convention

Within each branch, use the `refactor:` prefix to indicate no behavior change:

```
refactor: add Write-Log function with timestamp and level
refactor: add Get-NatStatus with IPForwarding check
refactor: wire all modules into WinRouter.psm1 dot-source
fix: correct path resolution in Import-Module call
docs: update README with new structure and usage
```

## Important: `WinRouter.psm1` as Last Step

The `WinRouter.psm1` file (which dot-sources all components) should be committed **incrementally**—add each `src/` module as its corresponding branch is merged into the integration branch. This ensures the main module never references non-existent files and allows testing after each partial merge.

Example after merging `refactor/core`:

```powershell
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\Elevation.ps1"
```

After merging `refactor/network`:

```powershell
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\Elevation.ps1"
. "$PSScriptRoot\network\Get-Interfaces.ps1"
# ... and so on
```

This approach allows validating the module loading chain at each step before reaching the `refactor/entrypoint` branch.
