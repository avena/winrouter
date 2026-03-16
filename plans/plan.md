# WinRouter Modularization Plan

## Objective

Transform the existing `config-nat-multi.ps1` script into a modular PowerShell structure with a main entry point `start-network.ps1` that loads modules from a `src/` directory. This plan is based on the provided tips and a more detailed modular structure.

## Proposed Structure

```
winrouter/
├── start-network.ps1          # entry point: self-elevation, loads modules, presents menu
├── README.md
│
├── src/
│   ├── WinRouter.psm1         # main module that dot-sources all components
│   │
├── core/
│   ├── Logger.ps1         # Write-Log, Write-LogCmd functions
│   ├── Elevation.ps1      # self-elevation, admin checks
│   └── Scoop.ps1          # Scoop integration (install/update apps)

│   │
│   ├── network/
│   │   ├── Get-Interfaces.ps1     # interface analysis and reporting
│   │   ├── Set-StaticIP.ps1       # configure static IP on interface
│   │   └── Remove-StaticIP.ps1    # remove IP from interface
│   │
│   ├── nat/
│   │   ├── Get-NatStatus.ps1      # list NAT rules and IPForwarding status
│   │   ├── New-NatRule.ps1        # create NetNat rule
│   │   └── Remove-NatRule.ps1     # remove NetNat rule(s)
│   │
│   ├── portforward/
│   │   ├── New-PortForward.ps1    # add portproxy rule (SSH:22, HTTP:80, custom)
│   │   ├── Get-PortForward.ps1    # list portproxy rules
│   │   └── Remove-PortForward.ps1 # remove portproxy rule
│   │
├── docker/
│   ├── Get-DockerNetworks.ps1  # list Docker bridge networks
│   └── New-DockerNat.ps1       # add NAT for Docker networks
│
└── wsl/                   # WSL 2 specific integration
    ├── Get-WslStatus.ps1         # Check version and running state
    ├── Get-WslNetworkConfig.ps1  # Detect NAT vs Mirrored mode
    ├── Invoke-WslPortForward.ps1 # Automate detection + proxy + firewall
    └── Test-WslConnectivity.ps1  # Diagnostic tools

│
└── logs/                      # generated at runtime, should be in .gitignore
```

## Tarefas

- [x] **1. Estrutura de Diretórios:** Criar a estrutura de diretórios em `src/` com as subpastas: `core`, `network`, `nat`, `portforward`, `docker`, `wsl`.
- [x] **2. Módulo Principal:** Criar o arquivo `WinRouter.psm1` em `src/` que fará o dot-source de todos os arquivos `.ps1` nas subpastas.
- [x] **3. Módulos Core:**
  - [x] Criar `Logger.ps1` com as funções `Write-Log` and `Write-LogCmd`.
  - [x] Criar `Elevation.ps1` com a lógica de auto-elevação e checagens de administrador.
  - [ ] Criar `Scoop.ps1` para integração com o gerenciador de pacotes Scoop.
- [x] **4. Módulos de Rede:**
  - [x] Criar `Get-Interfaces.ps1` para análise e relatório das interfaces.
  - [x] Criar `Set-StaticIP.ps1` para configuração de IP estático.
  - [x] Criar `Remove-StaticIP.ps1` para remoção de IP.
  - [ ] Criar `Get-WslIP.ps1` para descoberta dinâmica do IP do WSL (baseado no `forward-ssh.ps1`).
- [x] **5. Módulos NAT:**
  - [x] Criar `Get-NatStatus.ps1` para listar as regras de NAT e o status do `IPForwarding`.
  - [x] Criar `New-NatRule.ps1` para a criação de regras `NetNat`.
  - [x] Criar `Remove-NatRule.ps1` para a remoção de regras `NetNat`.
- [ ] **6. Módulos de Port Forwarding:**
  - [ ] **6.1 `New-PortForward.ps1`**: Criar função para adicionar redirecionamentos.
    - [ ] Implementar `netsh interface portproxy add v4tov4`.
    - [ ] Integração com Firewall (`New-NetFirewallRule`) para liberação automática.
    - [ ] Suporte a alvos dinâmicos (WSL, Docker) usando helpers.
  - [ ] **6.2 `Get-PortForward.ps1`**: Listar redirecionamentos ativos (`portproxy` e status de Firewall).
  - [ ] **6.3 `Remove-PortForward.ps1`**: Remover redirecionamentos.
    - [ ] Limpeza do `portproxy`.
    - [ ] Remoção da regra correspondente no Firewall.
- [ ] **7. Módulos Docker:**
  - [ ] Criar `Get-DockerNetworks.ps1` para listar as redes `bridge` do Docker.
  - [ ] Criar `New-DockerNat.ps1` para adicionar NAT para as redes Docker.
- [x] **8. Ponto de Entrada:** Criar o `start-network.ps1` no diretório raiz com:
  - [x] Lógica de auto-elevação.
  - [x] Carregamento do módulo (`Import-Module src\WinRouter.psm1`).
  - [x] Menu principal de interface.
  - [x] Despacho de função baseado na seleção do usuário.
- [x] **9. Documentação:** Atualizar o `README.md` para documentar a nova estrutura e uso.
- [x] **10. Testes:** Testar a funcionalidade para garantir que corresponde ao script original.
- [ ] **11. Módulos WSL 2:**
  - [ ] **11.1 `Get-WslStatus.ps1`**: Verificar se o WSL está rodando e qual a versão (`wsl --version`, `wsl --list --running`).
  - [ ] **11.2 `Get-WslNetworkConfig.ps1`**: Detectar modo de rede (NAT vs Mirrored) lendo o `%USERPROFILE%\.wslconfig`.
  - [ ] **11.3 `Invoke-WslPortForward.ps1`**: Automatizar o fluxo completo (Detectar IP -> PortProxy -> Firewall).
  - [ ] **11.4 `Test-WslConnectivity.ps1`**: Diagnóstico de conectividade host-guest (Test-NetConnection, etc.).

## Benefits of This Approach

- Each `.ps1` file has a single responsibility, making code easier to debug and maintain
- Adding new functionality = creating new file in appropriate directory, automatically loaded
- Functions can be tested in isolation by dot-sourcing the specific file
- Clear separation of concerns: logging, elevation, network, NAT, portforward, Docker
- Follows PowerShell best practices for modular scripting

## System Information and IPv4 Configuration Notes

### System Information:

- **Windows**: Windows 11 (Primary focus)
- **Shell**: PowerShell 7 (pwsh)
- **Package Manager**: Scoop (recommended for app installation)
- **Focus**: IPv4-only configuration (IPv6 not supported)
- **Privileges**: Running with administrator privileges
- **Issues**: NAT rule creation/removal failures due to IPv6 compatibility issues (resolved by IPv6 removal)

### IPv4 Configuration Requirements:

- **IPv6 is not supported** in WinRouter NAT operations
- All NAT rules must use IPv4 addresses exclusively
- Error handling focuses on system compatibility rather than IPv6 fallbacks
- Clear error messages for system compatibility issues

### IPv6 Guidelines:

**IPv6 is explicitly not supported** in WinRouter NAT operations for the following reasons:

1. **Conceptual Evolution**: IPv6 was designed with ~340 undecillion addresses (2^128) to provide every device with a **Global Unicast Address (GUA)**, natively eliminating the need for NAT.
2. **NAT as a Workaround**: NAT exists to share limited IPv4 addresses (~4.3B). In IPv6, translation (NAT) is technically unnecessary and breaks native end-to-end communication.
3. **Compatibility Issues**: Windows WinNAT often triggers "IPV6 sem suporte" when forced to apply IPv4 NAT logic to IPv6.
4. **Modern Alternative**: For WSL 2, **Mirrored Mode** (WSL 2.0.0+) provides native IPv6 support, removing the need for `netsh portproxy` and NAT.
5. **Security Shift**: In IPv6, since there is no "NAT protection," **explicit firewall rules** (`New-NetFirewallRule`) are mandatory for each exposed port.
6. **Complexity Reduction**: Removing IPv6 simplifies the codebase and prevents WinNAT driver conflicts.

### Development Guidelines:

1. **NAT Functions**: All NAT-related functions must be IPv4-only
2. **No IPv6 Parameters**: Do not add IPv6-related parameters to NAT functions
3. **Error Handling**: Focus on system compatibility rather than IPv6 fallbacks
4. **Documentation**: Clearly state IPv6 is not supported in function help

### Troubleshooting Guidelines:

1. **System Compatibility Error**: "Não há suporte à operação solicitada" occurs during NAT operations
2. **Root Cause**: System compatibility issues, not IPv6 problems
3. **Solution**: Focus on system compatibility and Windows version updates
4. **No IPv6 Troubleshooting**: IPv6 is not supported, so IPv6-related troubleshooting is not applicable

### For more information, see:

- `src/nat/New-NatRule.ps1`: IPv4-only NAT creation implementation
- `src/nat/Remove-NatRule.ps1`: IPv4-only NAT removal implementation
- `docs/NAT_FIX_SUMMARY.md`: Complete IPv6 removal documentation
- `docs/TROUBLESHOOTING.md`: Comprehensive troubleshooting guide

## Next Steps

Please review this plan and provide feedback or approval to proceed with implementation.
