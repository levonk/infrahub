# 🏠 Home Lab In-a-Box

A comprehensive, containerized home lab environment providing transparent proxying, monitoring, logging, privacy-focused networking services, and artifact repository management.

## ✨ Features

### 🌐 Network Services
- **DNS**: Multi-layered resolution with ODoH, DNSSEC, caching, and ad/malware blocking
- **NTP**: Time synchronization with NTS and leap smearing support
- **Web Proxy**: Transparent HTTP/HTTPS proxying with caching and Tor anonymization
- **WireGuard VPN**: Secure remote access with network isolation and split-tunnel support

### 🔒 Privacy & Security
- Oblivious DNS over HTTPS (ODoH) for DNS privacy
- Network Time Security (NTS) for NTP
- Tor integration for web traffic anonymization (optional for direct mode, automatic for transparent mode)
- ECS stripping to prevent DNS fingerprinting
- Malware, ad, and tracker blocking via curated blocklists
- VPN clients can optionally route through Tor (SOCKS5:9050)

### 📦 Artifact Repositories & Development Tools
- **Sonatype Nexus**: Multi-format repository (Maven, npm, Docker, PyPI)
- **Verdaccio**: Lightweight npm package caching and private registry
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
   nano .env  # Set your HOST_IP and other preferences
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
| **Vector** | Log pipeline | 9598/tcp |
| **Elasticsearch** | Log storage | 9200/tcp, 9300/tcp |
| **Loki** | Log aggregation | 3100/tcp |
| **Prometheus** | Metrics | 9090/tcp |
| **Grafana** | Dashboards | 3000/tcp |
| **Jaeger** | Tracing | 16686/tcp, 9411/tcp |
| **WireGuard** | VPN | 51820/udp, 51821/udp |
| **LocalStack** | AWS Local | 4566/tcp |

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
