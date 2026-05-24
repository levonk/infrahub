# WSL2 DNS Port Conflict Issue

## Problem

WSL2's built-in DNS forwarder binds to `10.255.255.254:53`, preventing Docker from binding dnsdist to `0.0.0.0:53` on the host.

## Root Cause

1. WSL2 automatically creates a DNS forwarder at `10.255.255.254:53`
2. This prevents Docker from publishing container port 53 to host port 53
3. Docker silently fails or remaps to a random port
4. The WSL2 host cannot directly access Docker bridge network IPs (172.20.x.x)

## Current Status

- **Container-to-container DNS**: ✅ Working perfectly
- **Host-to-container DNS**: ❌ Not accessible via container IPs
- **Published ports**: ❌ Port 53 conflict with WSL DNS

## Workarounds

### Option 1: Use Container Network (Recommended for Testing)
Access DNS services from within the Docker network:

```bash
# Run tests from inside a container
docker compose exec dnsdist dig @172.20.255.51 example.com +short

# Or use dnsdist's own resolver
docker compose exec dnsdist dig @127.0.0.1 example.com +short
```

### Option 2: Disable WSL DNS Stub (Not Recommended)
This would require modifying `/etc/wsl.conf` on Windows side, which affects all WSL2 distributions.

### Option 3: Use Alternative Ports
Map DNS to non-conflicting ports:
- Container port 53 → Host port 5353
- Container port 5353 → Host port 15353

**Status**: Implemented in docker-compose.yml but host cannot reach bridge network.

## Solution for Production

In production (non-WSL2 environments), the port mappings will work correctly:
- Port 53 will be available for transparent DNS interception
- No WSL2 DNS forwarder conflict

## Testing Strategy

Update tests to:
1. Test DNS functionality within the Docker network (container-to-container)
2. Skip host-based DNS tests in WSL2 environments
3. Document that full DNS interception requires non-WSL2 deployment

## Related Files

- `docker-compose.yml` - DNS port mappings
- `tests/dns-leak-test.sh` - DNS test script
- `/etc/resolv.conf` - WSL2 DNS configuration
