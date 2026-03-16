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
│   ├── core/
│   │   ├── Logger.ps1         # Write-Log, Write-LogCmd functions
│   │   └── Elevation.ps1      # self-elevation, admin checks
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
│   └── docker/
│       ├── Get-DockerNetworks.ps1  # list Docker bridge networks
│       └── New-DockerNat.ps1       # add NAT for Docker networks
│
└── logs/                      # generated at runtime, should be in .gitignore
```

## Tarefas

- [ ] **1. Estrutura de Diretórios:** Criar a estrutura de diretórios em `src/` com as subpastas: `core`, `network`, `nat`, `portforward`, `docker`.
- [ ] **2. Módulo Principal:** Criar o arquivo `WinRouter.psm1` em `src/` que fará o dot-source de todos os arquivos `.ps1` nas subpastas.
- [ ] **3. Módulos Core:**
  - [ ] Criar `Logger.ps1` com as funções `Write-Log` and `Write-LogCmd`.
  - [ ] Criar `Elevation.ps1` com a lógica de auto-elevação e checagens de administrador.
- [ ] **4. Módulos de Rede:**
  - [ ] Criar `Get-Interfaces.ps1` para análise e relatório das interfaces.
  - [ ] Criar `Set-StaticIP.ps1` para configuração de IP estático.
  - [ ] Criar `Remove-StaticIP.ps1` para remoção de IP.
- [ ] **5. Módulos NAT:**
  - [ ] Criar `Get-NatStatus.ps1` para listar as regras de NAT e o status do `IPForwarding`.
  - [ ] Criar `New-NatRule.ps1` para a criação de regras `NetNat`.
  - [ ] Criar `Remove-NatRule.ps1` para a remoção de regras `NetNat`.
- [ ] **6. Módulos de Port Forwarding:**
  - [ ] Criar `New-PortForward.ps1` para adicionar regras de `portproxy`.
  - [ ] Criar `Get-PortForward.ps1` para listar as regras de `portproxy`.
  - [ ] Criar `Remove-PortForward.ps1` para remover as regras de `portproxy`.
- [ ] **7. Módulos Docker:**
  - [ ] Criar `Get-DockerNetworks.ps1` para listar as redes `bridge` do Docker.
  - [ ] Criar `New-DockerNat.ps1` para adicionar NAT para as redes Docker.
- [ ] **8. Ponto de Entrada:** Criar o `start-network.ps1` no diretório raiz com:
  - [ ] Lógica de auto-elevação.
  - [ ] Carregamento do módulo (`Import-Module src\WinRouter.psm1`).
  - [ ] Menu principal de interface.
  - [ ] Despacho de função baseado na seleção do usuário.
- [ ] **9. Documentação:** Atualizar o `README.md` para documentar a nova estrutura e uso.
- [ ] **10. Testes:** Testar a funcionalidade para garantir que corresponde ao script original.

## Benefits of This Approach

- Each `.ps1` file has a single responsibility, making code easier to debug and maintain
- Adding new functionality = creating new file in appropriate directory, automatically loaded
- Functions can be tested in isolation by dot-sourcing the specific file
- Clear separation of concerns: logging, elevation, network, NAT, portforward, Docker
- Follows PowerShell best practices for modular scripting

## System Information and IPv4 Configuration Notes

### System Information:

- **Windows**: Windows 10/11 with PowerShell 5.1+
- **Focus**: IPv4-only configuration (IPv6 not supported)
- **Privileges**: Running with administrator privileges
- **Issues**: NAT rule creation/removal failures due to IPv6 compatibility issues (resolved by IPv6 removal)

### IPv4 Configuration Requirements:

- **IPv6 is not supported** in WinRouter NAT operations
- All NAT rules must use IPv4 addresses exclusively
- Error handling focuses on system compatibility rather than IPv6 fallbacks
- Clear error messages for system compatibility issues

### IPv6 Guidelines:

**IPv6 is explicitly not supported** in WinRouter for the following reasons:

1. **Compatibility Issues**: IPv6 support varies significantly between Windows versions
2. **Common Failures**: "IPV6 sem suporte" errors are frequent on many systems
3. **Limited Practical Use**: Most users only need IPv4 NAT functionality
4. **Complexity Reduction**: Removing IPv6 simplifies code and reduces failure points

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
