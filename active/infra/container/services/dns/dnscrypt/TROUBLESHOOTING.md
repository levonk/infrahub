# DNSCrypt Proxy Troubleshooting

## Known Issues

### IPv4 Binding Bug (Custom Build Required)

**Issue**: DNSCrypt proxy fails to bind to IPv4 addresses when running as a non-root user on Alpine Linux, even when explicitly configured with `listen_addresses = ['0.0.0.0:5053']`. The service defaults to IPv6 binding (`:::5053`), which breaks container-to-container communication on IPv4 networks.

**Affected Versions**: Official releases up to and including the latest stable release at the time of this setup.

**Root Cause**: https://github.com/DNSCrypt/dnscrypt-proxy/discussions/2700

The issue stems from socket binding behavior when running with limited privileges. The non-root user context causes the application to prefer IPv6 binding even when IPv4 is explicitly configured.

**Solution**:
**Solution**:

This repository uses a **custom-built binary** compiled from a specific commit that fixes the IPv4 binding issue. The binary is located at:

```
/services/dns/dnscrypt/assets/usr/local/bin/dnscrypt-proxy
```

**Specific Fix**: Commit ac5087315c9c48eb1d113b42c69fa14e451a9a1c ("Listen `0.0.0.0` only on IPv4")

This commit ensures that when `0.0.0.0` is configured as a listen address, the service binds to IPv4 only, not IPv6. The binary is compiled with Go 1.24.0 for optimal performance and security.

**Build Details**:
- **Source**: https://github.com/DNSCrypt/dnscrypt-proxy (latest main branch)
- **Build Date**: October 25, 2025
- **Go Version**: 1.24.0
- **Configuration**: Statically linked, Alpine Linux compatible

**Verification**:

To verify the service is binding correctly to IPv4:

```bash
# Check if the service is listening on IPv4
docker exec <container-name> netstat -tlnp | grep 5053

# Expected output should show:
# tcp  0  0 0.0.0.0:5053  0.0.0.0:*  LISTEN  <pid>/dnscrypt-proxy
```

**Configuration**:

Ensure your `dnscrypt-proxy.toml` includes:

```toml
listen_addresses = ['0.0.0.0:5053']
```

Do NOT use hardcoded container IPs like `172.20.255.50:5053` as this breaks portability and environment-specific configurations.

**Future Improvements**:

Consider using Linux capabilities (`CAP_NET_BIND_SERVICE`) to allow the service to bind to privileged ports without running as root. This would improve security while maintaining IPv4 binding functionality.

## ODoH Configuration Issues

### Missing Relay Definition for ODoH Servers

**Issue**: dnscrypt-proxy logs critical errors:

```text
[CRITICAL] No relay defined for [odoh-crypto-sx] - Configuring a relay is required for ODoH servers
```

**Root Cause**: The ODoH server `odoh-crypto-sx` was referenced in the `[anonymized_dns]` routes but was missing a relay definition. All ODoH servers must have a corresponding relay entry.

**Solution**: Added `odoh-crypto-sx` to the routes list with its relay:

```toml
[anonymized_dns]
routes = [
  { server_name = 'odoh-cloudflare', via = ['odohrelay-crypto-sx'] },
  { server_name = 'odoh-crypto-sx', via = ['odohrelay-crypto-sx'] },  # Added this
  { server_name = 'odoh-id-gmail', via = ['odohrelay-crypto-sx'] },
  # ... other routes
]
```

**Files Updated**:

- `assets/etc/dnscrypt-proxy/dnscrypt-proxy.toml`
- `configs/dns/dnscrypt-proxy/dnscrypt-proxy.toml` (template)

## File Permissions Warning

### Config File World-Writable in /tmp

**Issue**: dnscrypt-proxy logs warning:

```text
[WARNING] [/tmp/dnscrypt-proxy.toml] can be modified by other system users because [/tmp] is writable by other users
```

**Root Cause**: The entrypoint script was copying the config to `/tmp`, which is world-writable and a security risk.

**Solution**:

1. Changed working directory from `/tmp` to `/var/cache/dnscrypt-proxy` (already created in Dockerfile)
2. Set secure permissions on the directory (700) and config file (600)
3. Updated `docker/entrypoint.sh` to enforce proper permissions

**Changes Made**:

```bash
WORKING_DIR="/var/cache/dnscrypt-proxy"
WORKING_CONFIG="${WORKING_DIR}/dnscrypt-proxy.toml"

# Ensure working directory exists with secure permissions
chmod 700 "$WORKING_DIR"

# Copy config with secure permissions
cp "$CONFIG_FILE" "$WORKING_CONFIG"
chmod 600 "$WORKING_CONFIG"
```

## IPv6 Listener Issue

**Issue**: Container had both IPv4 and IPv6 listeners configured, which could cause binding conflicts.

**Solution**: Removed IPv6 listener from configuration:

```toml
# Before
listen_addresses = ['0.0.0.0:{DNS_DNSCRYPT_PROXY_CONTAINER_PORT}', '[::1]:{DNS_DNSCRYPT_PROXY_CONTAINER_PORT}']

# After
listen_addresses = ['0.0.0.0:{DNS_DNSCRYPT_PROXY_CONTAINER_PORT}']
```

This ensures the service binds only to IPv4, consistent with the custom binary fix and container networking setup.

## Related Resources

- [DNSCrypt Proxy GitHub](https://github.com/DNSCrypt/dnscrypt-proxy)
- [Issue Discussion](https://github.com/DNSCrypt/dnscrypt-proxy/discussions/2700)
- [Official Documentation](https://github.com/DNSCrypt/dnscrypt-proxy/wiki)
