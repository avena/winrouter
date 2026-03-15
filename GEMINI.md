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
