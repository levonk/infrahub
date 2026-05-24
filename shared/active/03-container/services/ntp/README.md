# NTP Service Stack for Localnet

The NTP service slice packages chronyd with Home Lab In-a-Box defaults so hosts obtain accurate, secure time. It mirrors the @[/organize-localnet] pattern used by DNS, proxy, and AI-codeassist domains.

## ⭐ Highlights

- Hardened [chronyd](https://chrony.tuxfamily.org/) container with Network Time Security (NTS) and leap smearing enabled.
- Dual access modes: transparent interception on UDP/TCP :123 and direct access on UDP/TCP :1123.
- Configuration, Dockerfile, scripts, and docs co-located under `services/ntp/` for predictable maintenance.
- Makefile automation for build, lifecycle management, linting, and health checks.

## ☑️ Components

| Service     | Purpose                                      | Ports                                              | Resources                 |
|-------------|-----------------------------------------------|----------------------------------------------------|---------------------------|
| `chronyd`   | Local NTP authority with NTS + leap smearing  | Transparent `:123`, Direct `:1123`, NTS `:4460`, Metrics `:9123` | `./chronyd`                |

The stack runs on the `homelab` Docker network just like the monolithic compose definition it replaces.

## 🚀 Quick Start

```bash
cd apps/active/devops/localnet/services/ntp
cp ../../.env.example .env  # optional overrides
make build
make up
make health-check
```

### Health Check Expectations

- `make health-check` reports the container running and responsive to `chronyc tracking`.
- `chronyc sources` inside the container lists upstream sources with at least one reachable peer.
- Host tests (see `tests/ntp-accuracy-test.sh`) confirm <10 ms offset and stratum ≤2 after warm-up.

## 🔄 Configuration

- `chronyd/config/chrony.conf` mirrors the prior `configs/ntp/chrony.conf` file and remains the canonical source.
- All configuration changes should flow through this directory; update specs and docs accordingly.
- Any secrets (e.g., future TLS credentials) must live in `.env` or mounted secrets, never committed to git.

## 🔍 Observability

- **Metrics**: `http://localhost:${CHRONYD_METRICS_HOST_PORT:-9123}/` once the exporter lands in Phase 9.
- **Container logs**: `make logs` or `docker compose logs chronyd`.
- Prometheus scraping continues via the existing job pointing at `chronyd:9123`.

## 🧪 Testing & Validation

Always run the layered accuracy test after changing configuration or build artifacts:

```bash
cd apps/active/devops/localnet
tests/ntp-accuracy-test.sh
```

That script exercises upstream reachability, container health, host exposure, and accuracy thresholds.

## 🧭 Directory Layout

```
services/ntp/
├── README.md
├── Makefile
├── docker-compose.ntp.yml
├── chronyd/
│   ├── config/
│   │   └── chrony.conf
│   ├── docker/
│   │   └── Dockerfile.chronyd
│   └── scripts/
│       └── bootstrap.sh
└── internal-docs/
```

## 📌 Next Steps

1. Wire the service into `docker-compose.yml` via `include` and delete the inlined definition.
2. Update specs and architecture docs to reference the new locations.
3. Add a metrics exporter and enable the Prometheus target once Phase 9 work begins.

Please keep this document current whenever the stack or workflows evolve.
