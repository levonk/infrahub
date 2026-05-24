# Localnet Scripts

Utility scripts for managing and validating the homelab infrastructure.

## DNS IP Validation

### `validate-dns-ips.sh`

Validates that DNS container IP addresses match configuration across:
- `docker-compose.yml` (static IP assignments)
- `configs/dns/dnsdist.conf` (upstream server references)
- Running containers (actual assigned IPs)

**Usage:**
```bash
# Run after starting services
./scripts/validate-dns-ips.sh
```

**When to run:**
- After `docker compose up` (especially after `docker compose down`)
- After network recreation
- When DNS services are not working correctly
- As part of startup validation in CI/CD

**Exit codes:**
- `0` - All IPs match, configuration is valid
- `1` - IP mismatches detected, remediation needed

**Example output:**
```
=========================================
DNS IP Address Validation
=========================================

CoreDNS:
  Expected (docker-compose.yml): 172.20.0.7
  Expected (dnsdist.conf):       172.20.0.7
  Actual (running container):    172.20.0.7
  ✅ PASS: All IPs match

dnscrypt-proxy:
  Expected (docker-compose.yml): 172.20.0.5
  Expected (dnsdist.conf):       172.20.0.5
  Actual (running container):    172.20.0.5
  ✅ PASS: All IPs match

=========================================
✅ All DNS IP addresses are correctly configured
=========================================
```

**Why this is needed:**

dnsdist 2.1 cannot resolve Docker hostnames during config parsing, so it requires static IP addresses. When the Docker network is recreated (via `docker compose down`), containers may get different IPs from DHCP, causing DNS resolution failures.

This script detects mismatches and provides specific remediation steps.

## IP Allocation Strategy

DNS services use the **high IP range (`172.20.255.x`)** to avoid conflicts with Docker's DHCP:

```
Network: 172.20.0.0/16

172.20.0.1              - Gateway
172.20.0.2-254.254      - DHCP Range (all services)
172.20.255.50           - dnscrypt-proxy (static)
172.20.255.51           - coredns (static)
172.20.255.52-59        - Reserved for DNS
```

**Why high range?**
- Docker DHCP starts from bottom (`172.20.0.2`) and works upward
- DNS services at top (`172.20.255.x`) never conflict with DHCP
- Survives network recreation (`docker compose down`)

**See also:**
- [ADR: High IP Range for DNS](../internal-docs/adr/adr-dns-high-ip-range.md)
- [DNS Troubleshooting Guide](../docs/troubleshooting-dns.md)
- [Issue: DNS IP Conflicts](../internal-docs/issues/dns-ip-conflicts.md)

## Security Note

This script runs on the **host**, not inside containers. It uses `docker inspect` which requires access to the Docker socket. This is intentional and safe for host-side validation scripts.

**Never** mount `/var/run/docker.sock` inside application containers.
