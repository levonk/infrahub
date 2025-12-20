# 🏠 Home Lab In-a-Box

A comprehensive, containerized home lab environment providing transparent proxying, monitoring, logging, privacy-focused networking services, and artifact repository management.

## ✨ Features

### 🌐 Network Services
- **DNS**: Multi-layered resolution with ODoH, DNSSEC, caching, and ad/malware blocking
- **NTP**: Time synchronization with NTS and leap smearing support
- **Web Proxy**: Transparent HTTP/HTTPS proxying with caching and Tor anonymization
- **WireGuard VPN**: Secure remote access with network isolation and split-tunnel support

### 🔒 Privacy & Security
- **Egress Firewall**: Strict allowlist-based outbound traffic control
- Oblivious DNS over HTTPS (ODoH) for DNS privacy
- Network Time Security (NTS) for NTP
- Tor integration for web traffic anonymization (optional for direct mode, automatic for transparent mode)
- ECS stripping to prevent DNS fingerprinting
- Malware, ad, and tracker blocking via curated blocklists
- VPN clients can optionally route through Tor (SOCKS5:9050)

### 📦 Artifact Repositories & Development Tools
- **Sonatype Nexus**: Multi-format repository (Maven, npm, Docker, PyPI)
- **Verdaccio**: Lightweight npm package caching and private registry
- **Nix Cache & Artifacts**:
  - **Attic**: Multi-tenant Nix binary cache
  - **Harmonia**: Nix binary cache
  - **NCPS**: Nix Cache Proxy Server
  - **Nix Snapshotter**: Lazy-loading for container images
- **LocalStack**: Local AWS cloud stack (S3, DynamoDB, Lambda, SQS, SNS, etc.)

### 📊 Observability
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **Jaeger**: Distributed tracing
- **Elasticsearch + Loki**: Centralized logging
- **Vector**: High-performance log pipeline

### 🎯 Three-Tier Access Model
- **Tier 1 (Host)**: Explicit configuration - full control, can bypass services
- **Tier 2 (Services)**: Direct internet access for upstream queries (DNS, packages, time)
- **Tier 3 (Apps)**: Transparent interception - enforced routing, cannot bypass

See [Three-Tier Access Model](internal-docs/architecture-three-tier-access.md) for details.

## 🚀 Quick Start

### Prerequisites

- Docker Engine >= 24.0 (or Docker Desktop)
- Docker Compose >= 2.20
- **Works on:**
  - ✅ Windows 11 + Docker Desktop + WSL2
  - ✅ macOS + Docker Desktop
  - ✅ Linux (any distribution)
- 8GB RAM minimum (4 cores recommended)
- 50GB disk space minimum
- **No host network modifications required!**

### Installation

1. **Clone and navigate**:
   ```bash
   cd apps/active/devops/localnet
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   vi .env  # Set your HOST_IP and other preferences
   ```

3. **Start services** (no host setup needed!):
   ```bash
   make up
   ```

   **Note:** No `sudo` required! The transparent proxy runs entirely in containers.

5. **Verify health**:
   ```bash
   make health-check
   ```

6. **Access dashboards**:
   - Grafana: http://YOUR_HOST_IP:3000 (admin / changeme)
   - Prometheus: http://YOUR_HOST_IP:9090
   - Nexus: http://YOUR_HOST_IP:8081
   - Verdaccio: http://YOUR_HOST_IP:4873
   - Jaeger: http://YOUR_HOST_IP:16686

## 📖 Documentation

- [Quickstart Guide](docs/quickstart.md) - Detailed setup instructions
- [Transparent Proxy Usage](docs/transparent-proxy-usage.md) - **How to use with your containers**
- [Architecture](docs/architecture.md) - System design and diagrams
- [Service Chains](docs/service-chains.md) - DNS/NTP/Web/Logging flows
- [Port Mapping](docs/port-mapping.md) - All exposed ports
- [WireGuard VPN Setup](docs/wireguard-setup.md) - Remote access configuration
- [LocalStack Setup](docs/localstack-setup.md) - Local AWS development
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🛠️ Common Operations

```bash
# Start all services
make up

# Stop all services
make down

# Restart services
make restart

# View logs
make logs

# View logs for specific service
docker compose logs -f dnsdist

# Flush all caches
make flush-cache

# Run health checks
make health-check

# Update blocklists
docker compose exec dnsdist /blocklists/update-blocklists.sh

# Backup volumes
./scripts/backup-volumes.sh

# Restore volumes
./scripts/restore-volumes.sh
```

## 🧪 Testing

```bash
# DNS leak test
./tests/dns-leak-test.sh

# NTP accuracy test
./tests/ntp-accuracy-test.sh

# Proxy chain test
./tests/proxy-chain-test.sh

# Full integration test suite
cd tests/integration && bats .
```

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Devices                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              nftables + TPROXY (Transparent)                 │
│         DNS (53) → NTP (123) → HTTP/HTTPS (80/443)          │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
    ┌──────┐       ┌──────┐       ┌──────┐
    │ DNS  │       │ NTP  │       │ Web  │
    │Chain │       │Chain │       │Proxy │
    └───┬──┘       └───┬──┘       └───┬──┘
        │              │              │
        ▼              ▼              ▼
    dnsdist        chronyd         Envoy
        │              │              │
        ▼              │              ▼
    CoreDNS            │           Squid
        │              │              │
        ▼              │              ▼
 dnscrypt-proxy        │          Privoxy
        │              │              │
        ▼              ▼              ▼
      ODoH           NTS            Tor
        │              │              │
        └──────────────┴──────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Observability Stack │
            │  ─────────────────── │
            │  • Vector (Logs)     │
            │  • Prometheus        │
            │  • Grafana           │
            │  • Elasticsearch     │
            │  • Loki              │
            │  • Jaeger            │
            └──────────────────────┘
```

## 🔧 Configuration

All services are configured via:
- Environment variables (`.env`)
- Configuration files (`configs/`)
- Docker Compose (`docker-compose.yml`)

See [docs/quickstart.md](docs/quickstart.md) for detailed configuration options.

## 📦 Services

| Service | Purpose | Ports |
|---------|---------|-------|
| **dnsdist** | DNS load balancer & filter | 53/udp, 5353/udp, 8083/tcp |
| **CoreDNS** | DNS caching & DNSSEC | 53/udp, 9153/tcp, 8080/tcp |
| **dnscrypt-proxy** | Encrypted DNS (ODoH) | 5300/udp |
| **chronyd** | NTP with NTS | 123/udp, 1123/udp, 9123/tcp |
| **Envoy** | Web proxy & routing | 80/tcp, 443/tcp, 3129/tcp, 9901/tcp |
| **Squid** | Web caching | 3128/tcp |
| **Privoxy** | Content filtering | 8118/tcp |
| **Tor** | Anonymization | 9050/tcp |
| **Nexus** | Artifact repository | 8081/tcp, 8082/tcp |
| **Verdaccio** | npm registry | 4873/tcp |
| **Nix Attic** | Nix binary cache | 8083/tcp |
| **Nix Snapshotter** | Container image lazy-loading | 8989/tcp |
| **Nix NCPS** | Nix cache proxy | 5001/tcp |
| **Nix Harmonia** | Nix cache server | 5000/tcp |
| **Egress Firewall** | Outbound traffic control | - |
| **Vector** | Log pipeline | 9598/tcp |
| **Elasticsearch** | Log storage | 9200/tcp, 9300/tcp |
| **Loki** | Log aggregation | 3100/tcp |
| **Prometheus** | Metrics | 9090/tcp |
| **Grafana** | Dashboards | 3000/tcp |
| **Jaeger** | Tracing | 16686/tcp, 9411/tcp |
| **WireGuard** | VPN | 51820/udp, 51821/udp |
| **LocalStack** | AWS Local | 4566/tcp |

## 🔌 Default Port Configuration

All container ports are configured to be unique and non-overlapping. Each service has a corresponding host port binding for external access.

| Service | Instance | Container Port | Host Port | Protocol | Notes |
|---------|----------|-----------------|-----------|----------|-------|
| DNSDist | Transparent | 5354 | 15352 | UDP/TCP | Primary DNS entry point |
| DNSDist | Direct | 5355 | 15353 | UDP/TCP | Direct mode DNS |
| CoreDNS | DNS | 15353 | 15354 | UDP/TCP | Caching resolver |
| CoreDNS | Metrics | 9153 | 9153 | TCP | Prometheus metrics |
| CoreDNS | Health | 18080 | 27493 | TCP | Health check endpoint |
| DNSDist | Metrics | 8083 | 8083 | TCP | Metrics endpoint |
| dnscrypt-proxy | ODOH | 5053 | 5360 | UDP/TCP | Primary (Oblivious DNS over HTTPS) |
| dnscrypt-proxy | Anon | 5054 | 5361 | UDP/TCP | Fallback 1 (Anonymous) |
| dnscrypt-proxy | Std | 5055 | 5362 | UDP/TCP | Fallback 2 (Standard) |
| dnscrypt-proxy | DoH | 5056 | 5363 | UDP/TCP | Fallback 3 (DNS over HTTPS) |
| dnscrypt-proxy | Encrypted | 5057 | 5364 | UDP/TCP | Fallback 4 (Encrypted) |
| dnscrypt-proxy | Plaintext | 5058 | 5365 | UDP/TCP | Fallback 5 (Plaintext) |
| NTP | Transparent | 123 | 123 | UDP/TCP | Primary NTP |
| NTP | Direct | 1123 | 1123 | UDP/TCP | Direct mode NTP |
| Claude Code | Intercept API | 3001 | 3001 | TCP | API endpoint |
| Claude Code | Intercept UI | 5173 | 5173 | TCP | Web UI |

**Key Points:**
- ✅ All container ports are **unique** (no conflicts)
- ✅ All services have **HOST_PORT** bindings for external access
- ✅ **Port 53 is avoided** (WSL2 limitation on Windows)
- ✅ **Fallback order honored**: ODOH → Anon → Std → DoH → Encrypted → Plaintext
- ✅ Ports can be customized via environment variables in `.env`

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

See [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

Built with official container images from:
- PowerDNS, CoreDNS, Envoy, Grafana Labs, Elastic, Sonatype, and many others
- Community-maintained blocklists: StevenBlack, AdAway, PhishTank, EasyList

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-20
