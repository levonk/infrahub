# 📚 Home Lab In-a-Box Documentation

Comprehensive documentation for deploying and using the Home Lab infrastructure.

---

## 🚀 Getting Started

### Quick Links

- **[Main README](../README.md)** - Project overview and quick start
- **[Installation & Setup](#-installation--setup)** - Deploy the Home Lab
- **[Client Configuration](#️-client-configuration)** - Configure devices to use services
- **[Reference](#-reference)** - Technical details and troubleshooting

---

## 📋 Installation & Setup

### Server Setup

1. **Prerequisites Check**
   - Docker Engine >= 24.0
   - Docker Compose >= 2.20
   - Linux kernel >= 5.10 with nftables
   - 8GB RAM minimum (4 cores recommended)
   - 50GB disk space minimum

2. **Initial Configuration**

   ```bash
   cd apps/active/devops/localnet
   cp .env.example .env
   # Edit .env and set your HOST_IP
   ```

3. **Host System Setup** (requires sudo)

   ```bash
   sudo ./scripts/setup-host.sh
   ```

4. **Start Services**

   ```bash
   make up
   make health-check
   ```

For detailed server setup instructions, see the [Main README](../README.md).

---

## 🖥️ Client Configuration

Configure your devices to use the Home Lab services (DNS, NTP, Web Proxy, Artifact Repositories).

### Operating System Guides

Choose your operating system for step-by-step configuration instructions:

| OS | Guide | Description |
|----|-------|-------------|
| **🐧 Debian/Ubuntu Linux** | [Debian Setup Guide](./client-setup-debian.md) | systemd-resolved, APT, systemd-timesyncd |
| **🪟 Windows** | [Windows Setup Guide](./client-setup-windows.md) | PowerShell, Registry, Group Policy |
| **🍎 macOS** | [macOS Setup Guide](./client-setup-macos.md) | networksetup, scutil, Homebrew |

### Configuration Overview

Each guide covers:

1. **Base Network Services**
   - DNS (system-wide and per-application)
   - NTP (time synchronization)
   - Web Proxy (HTTP/HTTPS)

2. **Artifact Repositories**
   - NPM (Verdaccio)
   - Maven (Nexus)
   - Docker Registry (Nexus)
   - Python/PyPI (Nexus)

3. **Verification & Testing**
   - DNS resolution tests
   - NTP synchronization checks
   - Proxy connectivity tests
   - Repository access tests

4. **Troubleshooting**
   - Common issues and solutions
   - Diagnostic commands
   - How to revert changes

---

## 📖 Reference

### Architecture & Design

- **Service Chains** - How DNS, NTP, and Web requests flow through the system
- **Port Mapping** - Complete list of exposed ports and services
- **Network Topology** - Docker networks and container communication

### Services Overview

| Service | Purpose | Ports | Access |
|---------|---------|-------|--------|
| **dnsdist** | DNS load balancer & filter | 53, 5353, 8083 | Direct: port 5353 |
| **CoreDNS** | DNS caching & DNSSEC | 9153, 8080 | Via dnsdist |
| **dnscrypt-proxy** | Encrypted DNS (ODoH) | 5300 | Via CoreDNS |
| **chronyd** | NTP with NTS | 123, 1123, 9123 | Direct: port 1123 |
| **Envoy** | Web proxy & routing | 80, 443, 9901 | Transparent/Direct |
| **Squid** | Web caching | 3128 | Direct: port 3128 |
| **Privoxy** | Content filtering | 8118 | Via Squid |
| **Tor** | Anonymization | 9050 | Via Privoxy |
| **Nexus** | Multi-format repository | 8081, 8082 | Web: 8081 |
| **Verdaccio** | npm registry | 4873 | Web: 4873 |
| **Prometheus** | Metrics collection | 9090 | Web: 9090 |
| **Grafana** | Dashboards | 3000 | Web: 3000 |
| **Jaeger** | Distributed tracing | 16686, 9411 | Web: 16686 |
| **Elasticsearch** | Log storage | 9200, 9300 | API: 9200 |
| **Loki** | Log aggregation | 3100 | API: 3100 |

### Access Modes

**Transparent Mode** (Automatic):

- DNS: Port 53
- NTP: Port 123
- HTTP/HTTPS: Ports 80/443
- Requires nftables configuration on host

**Direct Mode** (Explicit):

- DNS: Port 5353
- NTP: Port 1123
- Proxy: Port 3128
- No host firewall configuration needed

---

## 🛠️ Operations

### Common Tasks

```bash
# View all available commands
make help

# Service management
make up              # Start all services
make down            # Stop all services
make restart         # Restart all services
make ps              # Show running containers

# Monitoring
make logs            # View logs (last 100 lines)
make logs-follow     # Follow logs in real-time
make health-check    # Run health checks
make stats           # Show resource usage

# Maintenance
make flush-cache     # Flush DNS and web caches
make update-blocklists  # Update DNS/web blocklists
make backup          # Backup all volumes
make restore         # Restore from backup

# Updates
make pull            # Pull latest container images
make config          # Validate configuration
```

### Monitoring Dashboards

Access via web browser (replace `HOST_IP` with your server IP):

- **Grafana**: `http://HOST_IP:3000` (admin / changeme)
- **Prometheus**: `http://HOST_IP:9090`
- **Jaeger**: `http://HOST_IP:16686`
- **Nexus**: `http://HOST_IP:8081`
- **Verdaccio**: `http://HOST_IP:4873`

---

## 🔧 Troubleshooting

### Quick Diagnostics

```bash
# Check container status
docker compose ps

# View logs for specific service
docker compose logs -f dnsdist
docker compose logs -f chronyd
docker compose logs -f envoy

# Test DNS from host
dig @localhost google.com
dig @localhost -p 5353 google.com  # Direct mode

# Test NTP from host
chronyc -h localhost sources

# Check nftables rules
sudo nft list ruleset | grep transparent_proxy
```

### Common Issues

**DNS not resolving**:

```bash
# Check dnsdist is running
docker compose ps dnsdist

# Check DNS port
nc -zvu localhost 53

# Check logs
docker compose logs dnsdist coredns
```

**NTP not synchronizing**:

```bash
# Check chronyd is running
docker compose ps chronyd

# Check NTP port
nc -zvu localhost 123

# Check logs
docker compose logs chronyd
```

**Proxy not working**:

```bash
# Check Envoy is running
docker compose ps envoy

# Test proxy
curl -I -x http://localhost:3128 https://google.com

# Check logs
docker compose logs envoy squid
```

### Getting Help

1. Check service logs: `docker compose logs <service>`
2. Run health checks: `make health-check`
3. Review configuration: `.env` and `docker-compose.yml`
4. Check firewall rules: `sudo nft list ruleset`

---

## 📦 Container Images

All services use official upstream images:

- **DNS**: PowerDNS dnsdist, CoreDNS, dnscrypt-proxy
- **NTP**: chrony/NTP
- **Proxy**: Envoy, Squid, Privoxy, Tor
- **Repositories**: Sonatype Nexus, Verdaccio
- **Observability**: Prometheus, Grafana, Jaeger, Elastic, Loki, Vector

---

## 🔒 Security Considerations

### Privacy Features

- **ODoH**: Oblivious DNS over HTTPS prevents DNS snooping
- **NTS**: Network Time Security for authenticated NTP
- **Tor**: Optional anonymization for web traffic
- **ECS Stripping**: Prevents DNS fingerprinting
- **DNSSEC**: DNS query validation

### Network Isolation

- All services run in isolated Docker network
- Transparent proxy requires explicit host configuration
- Direct mode available for controlled access
- No services exposed to internet by default

### Credentials

Default credentials (CHANGE THESE):

- Grafana: `admin` / `changeme`
- Elasticsearch: `elastic` / `changeme`
- Nexus: `admin` / (generated on first run, check logs)

---

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

## 📄 License

See [LICENSE](../LICENSE) file.

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-21
