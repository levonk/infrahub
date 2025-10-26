# DNS Service Stack for Localnet

A hardened DNS service stack that provides authoritative and recursive resolution, filtering, and metrics for the localnet environment. The stack combines dnsdist, CoreDNS, dnscrypt-proxy, and a blocklist compiler to deliver secure DNS capabilities with observability and policy controls.

## ⭐ Highlights

- Layered DNS architecture with dnsdist load balancing upstream resolvers and CoreDNS.
- Encrypted upstream resolution via dnscrypt-proxy with configurable resolvers.
- Automated blocklist compilation pipeline publishing to dnsdist.
- Built-in health checks, metrics endpoints, and logging targets for each service.
- Makefile automation for lifecycle management, linting, health verification, and blocklist refreshes.

## ☑️ Components

| Service            | Purpose                                               | Ports                        | Resources |
|--------------------|--------------------------------------------------------|------------------------------|-----------|
| `dnsdist`          | Edge DNS dispatcher, blocklist enforcement, telemetry | `53/udp`, `53/tcp`, `5353/*`, metrics `:8083` | `./dnsdist` |
| `coredns`          | Authoritative + stub resolver for internal zones      | Metrics `:9153`, health `:8080`            | `./coredns` |
| `dnscrypt-proxy`   | Encrypted recursive upstream resolver                 | Host `:5300 -> container :5053`            | `./dnscrypt` |
| `blocklist-compiler` | Builds CDB blocklist artifacts from curated sources  | n/a (run-once)                              | `services/dns/dns-blocklists` |

All services run on the `homelab` Docker network with static IP assignments for deterministic DNS routing.

## ⚙️ Prerequisites

- Docker + Docker Compose v2
- Localnet `.env` file at `apps/active/devops/localnet/.env`
- Service-specific config files under `apps/active/devops/localnet/configs/dns/`
- Optional: service-level `.env` in `services/dns/.env` (copy from `.env.example`)

## 🚀 Quick Start

```bash
cd apps/active/devops/localnet/services/dns
cp .env.example .env # adjust host IPs/ports as needed
make build
make up
make health-check
```

### Health Check Expectations

- `health.check.local` resolves through dnsdist.
- `dnscrypt-proxy` successfully resolves `cloudflare.com` via encrypted upstream.
- `blocklist.cdb` exists within the dnsdist container.

## 🔄 Blocklist Management

Blocklists live under `services/dns/dns-blocklists/mounts/blocklists/sources/` and compiled artifacts publish to `services/dns/dns-blocklists/mounts/blocklists/compiled/`.

- `make blocklists-refresh` runs the compiler container to regenerate artifacts.
- `make blocklists-view` inspects compiled outputs mounted in dnsdist.

Update sources by editing files in `services/dns/dns-blocklists/mounts/blocklists/sources/` and re-running the refresh target. Keep the curated lists under version control.

## 🔍 Observability

- **dnsdist metrics**: `http://localhost:${DNSDIST_METRICS_HOST_PORT:-8083}`
- **CoreDNS metrics**: `http://localhost:${COREDNS_METRICS_HOST_PORT:-9153}`
- **CoreDNS health**:  `http://localhost:${COREDNS_HEALTH_HOST_PORT:-8080}`
- Standard Docker logs through `make logs-*` targets.

Integrate these endpoints into Prometheus, Grafana, or preferred monitoring stack. Ensure metrics endpoints are firewalled when running outside local development.

## 🛡️ Security Practices

- All containers run without elevated privileges and have tightly scoped volumes.
- Static container IPs stay within reserved high range (`172.20.255.x`).
- Sensitive configuration data (API keys, upstream resolver secrets) should flow through `.env` or config files stored outside the repo.
- Avoid mounting `docker.sock`; only blocklist compiler writes to tmpfs for ephemeral data.
- Use HTTPS/TLS for external metrics ingestion.

## 🧪 Testing & Validation

Recommended before changes:

1. `make lint` – verify compose file structure and YAML syntax.
2. `make up && make health-check` – ensure services start cleanly.
3. `make logs-dnsdist` – confirm blocklist loading and resolver targets.
4. Functional smoke tests against internal domains and upstream queries.

## 🧭 Directory Layout

```
services/dns/
├── Makefile
├── README.md
├── docker-compose.dns.yml
├── .env.example
├── coredns/
├── dns-blocklists/
│   └── mounts/
│       └── blocklists/
│           ├── sources/
│           └── compiled/
├── dnscrypt/
└── dnsdist/
```

Each subdirectory houses Dockerfiles, configs, or scripts specific to the component. Additional documentation should stay alongside its service directory.

## 📌 Next Steps

- Wire metrics into centralized monitoring dashboards.
- Automate blocklist refresh cadence via scheduler or CI job.
- Add Molecule/pytest-based smoke tests for DNS responses via CI.
- Document custom internal zones within `configs/dns/coredns/` for reference.

---

Maintainers: update this document whenever the stack architecture changes or new operational procedures are introduced.
