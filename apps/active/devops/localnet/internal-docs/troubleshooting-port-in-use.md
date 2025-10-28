# Troubleshooting: Port Already in Use (Docker)

## Problem

When running `make clean` or `docker compose up`, you get an error:

```
Error response from daemon: failed to set up container networking: Address already in use
```

This typically means a port is already bound on the Windows host, preventing Docker containers from binding to it.

## Root Cause

On Windows/WSL2, system services (especially DNS services like `svchost.exe`) may be listening on ports that LocalNet services need. Common culprits:

- **Port 5353**: Windows/WSL2 DNS resolver
- **Port 53**: Windows reserves this for DNS
- **Port 5354**: May be used by other services

## Quick Diagnosis

### Windows PowerShell

Find which process is using a specific port:

```powershell
netstat -ano | findstr "5353" | Sort | Get-Unique
```

This shows all connections on port 5353. The last column is the Process ID (PID).

Get the process name from the PID:

```powershell
tasklist | findstr "PID_NUMBER"
```

Or use the automated script (see below).

### WSL/Linux

```bash
lsof -i :5353
```

## Solution

### Option 1: Use a Different Port (Recommended)

If the conflicting port is used by a system service you don't need, change the LocalNet service to use a different port.

**Example: DNSDist on port 5354 instead of 5353**

Edit `services/dns/docker-compose.dns.yml`:

```yaml
ports:
  - "${DNS_TRANSPARENT_HOST_PORT:-5354}:${DNS_TRANSPARENT_CONTAINER_PORT:-5353}/udp"
  - "${DNS_TRANSPARENT_HOST_PORT:-5354}:${DNS_TRANSPARENT_CONTAINER_PORT:-5353}/tcp"
```

Then restart:

```bash
make clean
```

### Option 2: Stop the Conflicting Service

If the service using the port isn't needed, stop it:

```powershell
# Find the service name
tasklist | findstr "PID_NUMBER"

# Stop it (example: svchost.exe for DNS)
Stop-Service -Name "Dnscache" -Force
```

**Warning**: Stopping system services may affect Windows functionality. Only do this if you understand the implications.

### Option 3: Restart Docker/WSL2

Sometimes Docker or WSL2 caches port bindings:

```powershell
# Restart WSL2
wsl --shutdown

# Or restart Docker Desktop
# (via GUI or: Restart-Service Docker)
```

## Automated Diagnosis Script

Use the PowerShell script in `scripts/diagnose-port-conflict.ps1` to automate the diagnosis:

```powershell
.\scripts\diagnose-port-conflict.ps1 -Port 5353
```

This script will:
1. Find all processes using the port
2. Show process names and details
3. Suggest next steps

## Prevention

- **Document port usage**: Keep a list of which LocalNet services use which ports
- **Use environment variables**: Override ports via `.env` instead of hardcoding
- **Monitor system services**: Be aware of Windows services that may conflict

## Related Files

- `services/dns/docker-compose.dns.yml` - DNSDist port configuration
- `scripts/diagnose-port-conflict.ps1` - Automated diagnosis script
- `.env.template` - Port configuration template
