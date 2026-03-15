# WinRouter

> PowerShell 7 toolkit to turn a Windows 11 machine into a fully configured
> software router: static IPs, multi-LAN NAT, Docker network integration,
> and port-forwarding rules — all from an interactive wizard with full audit log.

---

## Overview

WinRouter is a collection of PowerShell 7 scripts that automates the process of
configuring a Windows machine as a network gateway/router. Instead of manually
navigating Control Panel, Registry, and netsh commands, you run a single
interactive wizard that guides you through every step and logs everything.

**Typical use case:** A PC with 2+ network adapters where one connects to the
internet (WAN) and the others serve local devices, VMs, or Docker containers
(LAN). WinRouter sets up NAT so all internal networks share the WAN connection.

---

## Features

- [x] Auto-detects all network adapters (name, MAC, current IP, status)
- [x] Analyzes existing NAT rules and gateway IPs before touching anything
- [x] Interactive wizard: choose WAN, LANs, and subnet per interface
- [x] Configures static IPs (.1 gateway) on each LAN interface
- [x] Creates individual NetNat rules per subnet (WinNAT / NetNat API)
- [x] Enables IP Forwarding via Registry
- [x] Docker network NAT integration (bridge networks)
- [x] Port-forwarding rules (SSH :22, HTTP :80, custom ports)
- [x] Full CleanAll mode: removes NAT rules, resets IP Forwarding, removes gateway IPs
- [x] Self-elevation: auto-relaunches as Administrator if needed
- [x] Timestamped audit log saved next to the script

---

## Scripts

| File                   | Description                                               |
| ---------------------- | --------------------------------------------------------- |
| `config-nat-multi.ps1` | Main wizard: analyze, configure, or clean all             |
| `nat-manager.ps1`      | Quick list/clean of existing NAT rules                    |
| `nat-rede50.ps1`       | Legacy: single static config for 192.168.50.x (MAC-based) |

---

## Requirements

- Windows 10 / 11 (Pro, Enterprise, or Server)
- PowerShell 7+ (`pwsh`)
- 2 or more network adapters
- Administrator privileges (auto-elevated by the script)

---

## Usage

```powershell
# First run: unblock the file if downloaded from the internet
Unblock-File .\config-nat-multi.ps1

# Run the wizard (auto-elevates to Administrator)
pwsh -ExecutionPolicy Bypass -File .\config-nat-multi.ps1
```

### Wizard Flow

```
1. Analyze
   Reads IPForwarding, existing NAT rules, all interfaces (IP, MAC, gateway status)
   Prints a summary table and executive overview

2. Choose action
   S = Configure new NAT setup
   N = CleanAll (remove all NAT rules, reset IPForwarding, remove gateway IPs)
   Q = Quit without changes

3. Configure (if S)
   - Choose WAN interface (internet uplink)
   - Choose LAN interfaces (one or more)
   - Set subnet per LAN (default: 192.168.50.0/24, 60, 70... or custom)
   - Confirm, then apply

4. Optional modules (planned)
   - Docker bridge NAT
   - Port-forwarding rules (SSH, HTTP, custom)
```

---

## Log

Every run creates a timestamped log in the same folder as the script:

```
config-nat-multi-20260315-145700.log
```

Log format:

```
2026-03-15 14:57:00 [INFO]    INICIO NAT MANAGER + Config Multi
2026-03-15 14:57:01 [INFO]    Interface A: Name=[Wi-Fi] IP=[192.168.1.105] GW=[Free]
2026-03-15 14:57:05 [SUCCESS] NAT criado: NAT-B-MYPC -> 192.168.50.0/24
2026-03-15 14:57:06 [SUCCESS] IP configurado: Ethernet = 192.168.50.1/24
```

---

## Planned Modules

- [ ] `docker-nat.ps1` — detect Docker bridge networks, add NAT rules automatically
- [ ] `portforward.ps1` — add/remove netsh portproxy rules (SSH :22, HTTP :80, custom)
- [ ] `dhcp-check.ps1` — verify DHCP server is handing out addresses on each LAN
- [ ] `firewall-rules.ps1` — open/close Windows Firewall rules per interface
- [ ] `status.ps1` — read-only overview of current state (no changes)

---

## Architecture

```
[WAN: Internet]
      |
      | (e.g. Wi-Fi or Ethernet from ISP)
      |
[Windows PC - WinRouter]
   IPForwarding = 1
      |
      |--- [LAN A: Ethernet  192.168.50.1/24] --> local devices / servers
      |--- [LAN B: USB-ETH   Do not change the values ] --> VMs / lab network
      |--- [LAN C: Docker    Do not change the values ] --> containers
```

---

## License

MIT

---

**Aviso:** Não edite os arquivos dentro da pasta `old-base-scripts`. Eles são mantidos para referência.
