# Troubleshooting Guide

## Common Issues and Solutions

### Port Conflicts

#### DNS Port 5353 Already in Use

**Symptoms:**
```
Error response from daemon: ports are not available: exposing port UDP 0.0.0.0:5353
bind: Only one usage of each socket address is normally permitted
```

**Cause:**
Port 5353 is commonly used by:
- **mDNS (Multicast DNS)** - Bonjour/Avahi service discovery
- **Windows DNS Client** service
- **macOS mDNSResponder**
- Multiple network adapters with mDNS enabled

**Solution 1: Change the Port (Recommended)**

Edit `.env` file:
```bash
# Change DNS direct port from 5353 to 15353
DNS_DIRECT_PORT=15353
```

Then access DNS using the new port:
```bash
# Windows
nslookup example.com 127.0.0.1 -port=15353

# Linux/macOS
dig example.com @localhost -p 15353
```

**Solution 2: Identify and Stop Conflicting Services**

On Windows:
```powershell
# Find what's using port 5353
netstat -ano | findstr :5353

# Identify the processes
tasklist | findstr "PID_FROM_ABOVE"

# Common culprits:
# - svchost.exe (DNS Client)
# - mDNSResponder.exe (Bonjour)
# - Multiple instances on different network adapters
```

**Solution 3: Disable mDNS/Bonjour (Not Recommended)**

This may break service discovery features:
```powershell
# Stop Bonjour service (if installed)
net stop "Bonjour Service"
sc config "Bonjour Service" start= disabled
```

---

### Network Conflicts

#### Docker Network Subnet Overlap

**Symptoms:**
```
Error response from daemon: Pool overlaps with other one on this address space
```

**Solution:**

Edit `.env` file:
```bash
# Change from 172.20.0.0/16 to another subnet
DOCKER_NETWORK_SUBNET=172.20.0.0/16
```

Then clean up and restart:
```bash
docker network prune -f
make up
```

#### IP Address Conflicts

**Symptoms:**
```
Error response from daemon: failed to set up container networking: Address already in use
```

**Cause:**
Docker containers competing for the same IP address, typically after network recreation.

**Solution:**

Our DNS services use **high IP range (`172.20.255.x`)** to avoid conflicts with DHCP:

- **DNS Services**: `172.20.255.50-59` (static, reserved)
- **Other Services**: `172.20.0.2-254.254` (DHCP assigned)

If you see IP conflicts:

```bash
# 1. Verify DNS IP configuration
./scripts/validate-dns-ips.sh

# 2. If validation fails, recreate DNS services
docker compose down dnsdist coredns dnscrypt-proxy
docker compose up -d dnscrypt-proxy coredns dnsdist

# 3. Verify again
./scripts/validate-dns-ips.sh
```

**For detailed DNS troubleshooting, see:** [DNS Troubleshooting Guide](troubleshooting-dns.md)

**Why high IP range?**
- Docker DHCP starts from bottom (`172.20.0.2`) and works upward
- DNS services at top (`172.20.255.x`) never conflict with DHCP
- Survives network recreation (`docker compose down`)
- See [ADR: High IP Range for DNS](../internal-docs/adr/adr-dns-high-ip-range.md) for full rationale

---

### Container Issues

#### Container Won't Start

**Check logs:**
```bash
# View logs for specific service
docker compose logs dnsdist
docker compose logs transparent-gateway

# Follow logs in real-time
docker compose logs -f dnsdist
```

**Common fixes:**
```bash
# Restart specific service
docker compose restart dnsdist

# Rebuild and restart
docker compose up -d --build dnsdist

# Full reset
make down
make up
```

#### Container Exits Immediately

**Check for:**
1. Configuration file syntax errors
2. Missing environment variables
3. Port conflicts
4. Volume mount issues

```bash
# Inspect container
docker compose ps
docker inspect homelab-dns-dnsdist

# Check exit code
docker compose ps -a
```

---

### DNS Issues

#### DNS Not Resolving

**Test DNS directly:**
```bash
# Test direct port
dig example.com @localhost -p 15353

# Test with specific query type
dig example.com @localhost -p 15353 A
dig example.com @localhost -p 15353 AAAA
```

**Check DNS service:**
```bash
# Verify dnsdist is running
docker compose ps dnsdist

# Check dnsdist logs
docker compose logs dnsdist | tail -50

# Test from inside container
docker compose exec dnsdist dig example.com @127.0.0.1 -p 5353
```

#### DNS Queries Blocked

**Check blocklist:**
```bash
# View dnsdist logs for blocked queries
docker compose logs dnsdist | grep "REFUSED"

# Temporarily disable blocklist (edit dnsdist.conf)
# Comment out: addAction(AllRule(), PoolAction("blocked"))
docker compose restart dnsdist
```

---

### Transparent Proxy Issues

#### Application Not Using Transparent Proxy

**Verify configuration:**
```yaml
# In docker-compose.yml, ensure:
your-app:
  dns:
    - transparent-gateway  # Must use gateway as DNS
  networks:
    - homelab
```

**Test from inside app container:**
```bash
# Check DNS resolution
docker compose exec your-app nslookup example.com

# Check routing
docker compose exec your-app ip route

# Check DNS server
docker compose exec your-app cat /etc/resolv.conf
```

#### Transparent Gateway Not Intercepting

**Check gateway logs:**
```bash
docker compose logs transparent-gateway

# Should see iptables rules being applied
# Should see traffic being forwarded
```

**Verify iptables rules:**
```bash
docker compose exec transparent-gateway iptables -t nat -L -n -v
```

---

### Web Proxy Issues

#### Proxy Connection Refused

**Test proxy directly:**
```bash
# Test Squid proxy
curl -x http://localhost:3128 http://example.com

# Test with verbose output
curl -v -x http://localhost:3128 http://example.com
```

**Check proxy logs:**
```bash
docker compose logs squid
docker compose logs privoxy
```

#### HTTPS Sites Not Working

**Check SSL bump configuration:**
```bash
# Squid needs to be configured for SSL bumping
# Check squid.conf for ssl_bump directives
docker compose exec squid cat /etc/squid/squid.conf | grep ssl_bump
```

---

### VPN Issues

#### WireGuard Not Starting

**Check configuration:**
```bash
docker compose logs wireguard-direct
docker compose logs wireguard-transparent

# Check if ports are available
netstat -ano | findstr :51820
netstat -ano | findstr :51821
```

#### Can't Connect to VPN

**Verify:**
1. Firewall allows UDP ports 51820 and 51821
2. Router port forwarding configured
3. SERVERURL is correct in .env

```bash
# Test from client
ping YOUR_SERVER_IP

# Check if ports are open (from external network)
# Use online port checker or nmap
```

---

### Monitoring Issues

#### Grafana Dashboard Empty

**Check data sources:**
1. Open Grafana: http://localhost:3000
2. Go to Configuration → Data Sources
3. Verify Prometheus connection

**Check Prometheus:**
```bash
# Verify Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Check metrics
curl http://localhost:9090/api/v1/query?query=up
```

#### Prometheus Not Scraping

**Check prometheus.yml:**
```bash
docker compose exec prometheus cat /etc/prometheus/prometheus.yml

# Verify targets are configured
# Check logs
docker compose logs prometheus
```

---

### Performance Issues

#### High CPU Usage

**Check resource usage:**
```bash
docker stats

# Identify heavy containers
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Common causes:**
- Elasticsearch (high memory/CPU)
- Nexus (high memory)
- Too many concurrent requests

**Solutions:**
```bash
# Limit container resources in docker-compose.yml
services:
  elasticsearch:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

#### High Memory Usage

**Check memory:**
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

**Reduce memory:**
1. Limit Elasticsearch heap: `ES_JAVA_OPTS=-Xms2g -Xmx2g`
2. Limit Nexus heap: `INSTALL4J_ADD_VM_PARAMS=-Xms1g -Xmx2g`
3. Disable unused services

---

### LocalStack Issues

#### LocalStack Services Not Available

**Check health:**
```bash
curl http://localhost:4566/_localstack/health

# Should return JSON with service statuses
```

**Test AWS CLI:**
```bash
aws --endpoint-url=http://localhost:4566 s3 ls

# If fails, check:
# 1. LocalStack is running
# 2. Port 4566 is accessible
# 3. AWS CLI is configured correctly
```

---

### Browser Desktop Issues

#### VNC Connection Refused

**Check if running:**
```bash
docker compose ps browser-desktop

# Check logs
docker compose logs browser-desktop
```

**Test ports:**
```bash
# VNC port
telnet localhost 5900

# noVNC web interface
curl http://localhost:6080
```

#### Can't Access noVNC Web Interface

**Verify:**
1. Container is running
2. Port 6080 is not blocked by firewall
3. Access via: http://localhost:6080

**Check browser console for errors**

---

## Getting Help

### Collect Diagnostic Information

```bash
# System info
docker version
docker compose version

# Container status
docker compose ps

# All logs
docker compose logs > homelab-logs.txt

# Network info
docker network ls
docker network inspect homelab_homelab

# Volume info
docker volume ls
```

### Enable Debug Logging

Edit `.env`:
```bash
# Enable debug for specific services
DNSDIST_DEBUG=1
LOCALSTACK_DEBUG=1
```

### Reset Everything

```bash
# Nuclear option - removes all data
make down
docker volume prune -f
docker network prune -f
make up
```

---

## Still Having Issues?

1. Check the logs: `docker compose logs -f`
2. Verify .env configuration
3. Check firewall settings
4. Ensure Docker Desktop is running (Windows/macOS)
5. Try restarting Docker Desktop
6. Check for port conflicts with `netstat -ano | findstr :PORT`
