# DNSCrypt Proxy Custom Build Notes

## Build Summary

**Date**: October 25, 2025 (Updated Oct 26, 2025)  
**Binary Version**: 2.1.5  
**Go Version**: 1.24.0  
**Source Repository**: https://github.com/DNSCrypt/dnscrypt-proxy  
**Source Commit**: ac5087315c9c48eb1d113b42c69fa14e451a9a1c ("Listen `0.0.0.0` only on IPv4")

## Why a Custom Build?

The official DNSCrypt proxy releases contain a bug that prevents proper IPv4 binding when running as a non-root user on Alpine Linux. This custom build includes fixes from the development branch.

**Bug Reference**: https://github.com/DNSCrypt/dnscrypt-proxy/discussions/2700

## Build Process

The binary was built using Docker to ensure compatibility with Alpine Linux:

```bash
docker run --rm \
  -v /home/micro/p/gh/DNSCrypt/dnscrypt-proxy:/src \
  -w /src \
  golang:1.24.0-alpine \
  go build -o dnscrypt-proxy-bin ./dnscrypt-proxy
```

**Build Characteristics**:
- Statically linked (no external dependencies required)
- 64-bit x86-64 architecture
- Alpine Linux compatible
- Debug symbols included (not stripped)
- Size: ~19MB

## Binary Location

The binary is placed in the `assets/` directory which mirrors the container filesystem:

```bash
assets/usr/local/bin/dnscrypt-proxy  →  /usr/local/bin/dnscrypt-proxy (in container)
assets/etc/dnscrypt-proxy/            →  /etc/dnscrypt-proxy/ (in container)
```

**Full path**:

```bash
/home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/dns/dnscrypt/assets/usr/local/bin/dnscrypt-proxy
```

## Configuration

The service uses the configuration file at:

```
/services/dns/dnscrypt/assets/etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

**Critical Configuration**:
```toml
listen_addresses = ['0.0.0.0:5053']
```

This ensures the service binds to all IPv4 interfaces, enabling container-to-container communication.

## Testing

Verify the binary works:

```bash
./dnscrypt-proxy -version
# Output: 2.1.14
```

Verify IPv4 binding in Docker:

```bash
docker exec <container-name> netstat -tlnp | grep 5053
# Should show: tcp  0  0 0.0.0.0:5053  0.0.0.0:*  LISTEN
```

## Future Considerations

1. **Monitor Upstream**: Watch for official releases that include the IPv4 binding fix
2. **Security Capabilities**: Consider using `CAP_NET_BIND_SERVICE` to allow non-root binding to port 5053
3. **Automated Builds**: Consider setting up CI/CD to automatically rebuild when upstream releases new versions

## Related Documentation

See `TROUBLESHOOTING.md` for detailed information about the IPv4 binding bug and workarounds.
