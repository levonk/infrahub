# Agent Documentation: Ansible

## CRITICAL: Container Management via Ansible Modules — NEVER `docker compose`

**All container lifecycle MUST use `community.docker` Ansible modules.** See `AGENTS.md` (root repo) → "Architectural Invariants → 4. Ansible modules manage containers — NEVER `docker compose`" for the full rule.

- ✅ `community.docker.docker_container` — manage containers
- ✅ `community.docker.docker_network` — manage networks
- ✅ `community.docker.docker_volume` — manage volumes
- ✅ `community.docker.docker_image` — build/pull images
- ❌ `ansible.builtin.shell: docker compose up/down/build`
- ❌ Copying `docker-compose*.yml` to targets
- ❌ `ansible.builtin.shell: docker network connect/disconnect`
- ❌ `.env` file variable interpolation

## Root Cause First - No Workarounds

**Root causing is essential. Do not work around long-term problems unless explicit permission is granted.**

- When a deployment fails, investigate the actual cause before retrying or trying alternatives.
- Failing early and surfacing the issue is preferable to working around it and raising the problem later.
- If a credential is expired, say so and tell the user where to update it - do not attempt manual authentication loops, state copying, or other band-aids.
- If a container keeps restarting, find out why (check restart count, logs, exit codes) before redeploying.
- Do not chain workaround on top of workaround. Each failed attempt should inform the next, not paper over the previous failure.
- When you encounter an existing resource that conflicts with a new one (e.g., a node already exists in Tailscale), stop and surface the conflict to the user. Do not proceed with a renamed variant without permission.

## Port Conflict Checking

**When setting a port for a service (host port binding, container port, or healthcheck port), scan for conflicts before deploying.**

- Check `shared/active/02-config/ansible/infrastructure/ports.yml` and `levonk/active/02-config/ansible/infrastructure/ports.yml` for already-assigned ports.
- Check `docker ps` on the target host for any container already binding the port.
- Check host services (e.g., CoreDNS on port 53, sshd on 22) that may conflict.
- If a conflict is found, stop and surface it — do not silently pick another port.
- Common conflict sources on the OCI server: port 53 (CoreDNS), port 8080 (Traefik dashboard, SearXNG), port 8443 (various proxies).

## community.docker.docker_container Parameter Names

**The `community.docker.docker_container` module uses different parameter names than `docker compose` / `docker run`. Using the compose-style names fails with "Unsupported parameters" errors.**

| ❌ Invalid (compose-style) | ✅ Valid (community.docker) |
|---|---|
| `cap_add` | `capabilities` |
| `cap_drop` | `cap_drop` (same — this one is valid) |
| `security_opt` | `security_opts` |
| `log_opt` | `log_options` |
| `expose` | `exposed_ports` |
| `ports` | `published_ports` (both work, `ports` is a valid alias) |
| `links` | `links` (same) |
| `volumes_from` | `volumes_from` (same) |
| `restart` | `restart_policy` + `restart_retries` |
| `state: restarted` | `state: started` + `restart: true` |
| `state: running` | `state: started` |
| `healthcheck.interval: 30` (integer) | `healthcheck.interval: "30s"` (string with unit suffix) |
| `healthcheck.timeout: 10` (integer) | `healthcheck.timeout: "10s"` (string with unit suffix) |
| `healthcheck.start_period: 40` (integer) | `healthcheck.start_period: "40s"` (string with unit suffix) |

Additional gotchas:
- **Env values must be strings**: `PORT: 8080` fails with "Non-string value found for env option". Use `PORT: "8080"` or `PORT: "{{ my_port | string }}"`.
- **`state: restarted` is invalid**: Use `state: started` with `restart: true` in handlers.
- **Base image CMD is not inherited**: When you set a custom `ENTRYPOINT` in a Dockerfile and deploy via `docker_container`, you must also set `CMD` in the Dockerfile — the Ansible module does not inherit the base image's CMD unless you explicitly pass `command:`.

## Quick Reference

- **Project Type**: Ansible infrastructure and roles for cloud server deployment
- **Build System**: Devbox + Just
- **Test Framework**: Molecule for role testing (currently blocked due to Python docker module dependency)
- **Package Manager**: pnpm for Nix, but Ansible packages via devbox

## Role Naming Convention

All hardening roles follow the pattern `common-{platform}-{concern}-hardening` in the **directory name**, with `role_name: common_{platform}_{concern}_hardening` (underscores) in `meta/main.yml` to satisfy ansible-lint's `role-name` rule. Other roles use functional-group prefixes (`dns-`, `proxy-`, `vpn-`, `ai-`).

Windows platform versions in meta must use `["all"]`, not `["10"]`/`["11"]` (schema rejects those). Enterprise Linux (Oracle Linux) uses platform name `EL` with versions `["8", "9"]`.

See [`internal-docs/troubleshooting/ansible-lint.md`](../../../internal-docs/troubleshooting/ansible-lint.md) for the full naming rules and lint troubleshooting.

## Playbook-to-Inventory Mapping

| Playbook | Inventory | Host group | OS | Hosts |
|---|---|---|---|---|
| `cloud-server-bootstrap.yml` | `levonk/.../inventories/oci.yml` | `cloud_servers`, `isolation_vms` | Oracle Linux (EL) | OCI cloud server, QEMU isolation VMs |
| `harden-windows-host.yml` | `levonk/.../inventories/windows-docker.yml` | `windows_docker_hosts` | Windows | dtop202311 (Windows Docker Desktop) |
| `bootstrap-macos-host.yml` | `levonk/.../inventories/macos-hosts.yml` | `macos_hosts` | macOS | macOS hosts |
| `localnet-tailscale.yml` | `levonk/.../inventories/localnet.yml` | `vpn_tailscale_clients` | Linux | localnet hosts |
| `bootstrap-ai-inference-host.yml` | `levonk/.../inventories/localnet.yml --limit kckinai` | `vpn_tailscale_clients` | Linux | kckinai (NVIDIA inference host) |

When adding a new role to a playbook, check this table to know which playbook(s) cover which hosts. Use `--tags <role-tag>` to deploy only that role across all inventories.

## DNS Architecture (Two-Layer)

The shared roles provide a two-layer DNS architecture for Tailscale-attached hosts. Clients opt in by setting Tailscale FQDN variables in their `infrastructure/domains.yml` and per-host `cloudflare_ddns_hostname` in their inventory.

### Layer 1: CNAME → Tailscale FQDN (Primary)

**Role**: `cloudflare-dns`  
**Playbook**: `playbooks/configure-cloudflare-dns.yml`

Service domains (`*.<base>`) are CNAMEs to Tailscale FQDNs (`*.<tailnet>`). This decouples Cloudflare DNS from ephemeral Tailscale IPs — if Tailscale reassigns the IP, only Tailscale's internal DNS updates. See AGENTS.md (root) → Architectural Invariant #9 for the full rule.

### Layer 2: DDNS → Public IP (Fallback)

**Role**: `cloudflare-ddns`  
**Playbook**: `playbooks/deploy-cloudflare-ddns.yml`

A lightweight container on each host updates an A record (`{hostname}.mach.{domain}`) with the host's **public IP** every 5 minutes. This provides a non-Tailscale fallback — if Tailscale MagicDNS is down but the host has internet, the `*.mach.{domain}` records still resolve. See `roles/cloudflare-ddns/README.md` for details.

### Variables (shared defaults, overridden by client)

| Variable | Shared default | Client override |
|----------|---------------|-----------------|
| `infra_tailscale_tailnet` | `example.ts.net` | `<tailnet>` |
| `infra_tailscale_fqdn_cloud_server` | `{{ infra_tailscale_tailnet }}` | `oci.<tailnet>` |
| `infra_tailscale_fqdn_inference_host` | (none) | `kckinai.<tailnet>` |
| `cloudflare_ddns_hostname` | (none — set per-host) | `"oci"`, `"kckinai"` |

### Clients Using This Feature

- **levonk**: `oci.mach.<base>` → public IP, `kckinai.mach.<base>` → public IP. See `levonk/AGENTS.md` → "DNS & DDNS Rollout" for the client-specific deployment status.

## Web Proxy Chain Architecture

The shared `proxy-web` role deploys a 4-layer web proxy chain for HTTPS
interception, content filtering, caching, and egress routing. It mirrors the
DNS chain's dual-platform deployment pattern (Linux/OCI + Windows).

### Chain Flow

```
Client
  ↓ (explicit: port 3127/3128, transparent: nftables 80/443)
MITM Proxy (mitmproxy) — HTTPS decryption, CA management
  ↓
Privoxy — content filtering, header sanitization
  ↓
Varnish — HTTP cache, stale-while-revalidate, stale-if-error
  ↓ (cache miss)
Gost — egress multiplexer
  ↓                    ↓
Direct              Tor (shared with DNS chain)
  ↓                    ↓
Internet            Internet
```

### Role: proxy-web
### Playbook: `playbooks/deploy-proxy-web-stack.yml`
### Validation: `playbooks/validate-proxy-web.yml`
### Targets: `windows_docker_hosts` (dtop202311) + `cloud_servers` (oci-cloud-server)

### Variables (shared defaults, overridden by client)

| Variable | Shared default | Source |
|----------|---------------|--------|
| `proxy_web_mitm_ip` | `172.26.255.80` | `infra_network_ip_proxy_mitm` |
| `proxy_web_privoxy_ip` | `172.26.255.81` | `infra_network_ip_proxy_privoxy` |
| `proxy_web_varnish_ip` | `172.26.255.82` | `infra_network_ip_proxy_varnish` |
| `proxy_web_gost_ip` | `172.26.255.83` | `infra_network_ip_proxy_gost` |
| `proxy_web_tor_socks5_ip` | `172.26.255.70` | `infra_network_ip_dns_tor_proxy` (shared with DNS chain) |

### Just Recipes

```bash
# Deploy to Windows
just ansible-deploy-proxy-web

# Deploy to OCI
just ansible-deploy-proxy-web-oci

# Validate
just ansible-validate-proxy-web
just ansible-validate-proxy-web-oci
```

### Prerequisites

- DNS chain deployed (Tor proxy at `172.26.255.70:9050` is shared)
- `localnet-network` exists (created by DNS chain role)
- Gost image built: `just docker-build-push localnet-proxy-gost`

### Cross-Cluster Topology

Both clusters run the full chain independently — no cross-cluster failover
(web proxy is stateful: MITM sessions, cache state, CA certs). See
`requirements/proxy/cross-cluster-web-proxy.md` for details.

### See Also

- `shared/docs/pipelines/web/complete-web-proxy-chain.mmd` — full architecture diagram
- `shared/docs/pipelines/web/requirements/mitm-ca-distribution.md` — CA certificate strategy
- `shared/docs/pipelines/web/requirements/caching-strategy.md` — Varnish vs Squid decision
- `shared/docs/pipelines/web/requirements/egress-routing.md` — Gost egress multiplexer config

## Devbox & Just Commands

**ALWAYS use `just` commands instead of `devbox run` for Ansible operations.**

### Molecule Testing (BLOCKED)

```bash
# Test specific role via Molecule
just molecule-test host-os-bootstrap
just molecule-test nix-installation
just molecule-test docker-engine

# Run all Molecule tests
just ansible-test-internal

# Manual container cleanup
just ansible-test-env-stop
```

**BLOCKER**: Molecule tests are currently blocked because:
- molecule-docker package doesn't exist in nixpkgs
- molecule requires Python docker module which isn't available
- molecule runs Ansible with restricted PATH (only Python package dirs), can't access system PATH where podman/docker binaries live
- Tried: podman driver, delegated driver, custom nix package with withPackages, python313Packages.podman (installed but molecule still can't find podman binary in Ansible PATH)
- Directory renamed from `molecule` to `.molecule` (molecule expects the directory to be named `.molecule`)

### Ansible Commands

```bash
# Lint all roles & playbooks
just ansible-lint

# Check playbook syntax
just ansible-syntax

# Run Molecule tests (Docker containers)
just ansible-test

# Deploy playbooks to OCI
just ansible-deploy-bootstrap
just ansible-deploy-vpn
just ansible-deploy-infra
just ansible-deploy-vms
just ansible-deploy-site

# Validate deployments
just ansible-validate-bootstrap
just ansible-validate-vpn
just ansible-validate-infra
just ansible-validate-vms
```

### Docker Test Environment

```bash
# Build test environment
just ansible-test-env-build

# Stop test container
just ansible-test-env-stop
```

## Repository Structure

```
shared/active/02-config/ansible/
├── roles/              # Ansible roles
│   ├── host-os-bootstrap/
│   ├── nix-installation/
│   └── docker-engine/
├── playbooks/          # Playbook files
├── group_vars/          # Group variables
├── inventories/        # Inventory files
└── collections/        # Ansible Galaxy collections
```

## Validation & Testing Layers

Every service should have three layers of validation:

### 1. Playbook validation (`validate-<service>.yml` in `playbooks/`)

Read-only, idempotent post-deployment checks that run against the same inventory(s) as the deployment.

- Use `tags: ["validate", "<service>"]` so `--tags validate` can run only checks.
- Record results in a `validation_results` fact and display a final summary; do not fail fast on the first failing check.
- Use `community.docker.docker_container_info` on Linux/OCI and `delegate_to: localhost` with `docker -H` on Windows Docker hosts (`community.docker` modules fail on Windows because `grp` is Unix-only).
- Use `ansible.builtin.uri`, `ansible.builtin.wait_for`, `ansible.builtin.command` for endpoint, DNS, and log checks.
- Add a `just ansible-validate-<service>` / `ansible-validate-<service>-internal` recipe and a matching `devbox.json` script when the playbook is created.

Existing examples: `validate-bootstrap.yml`, `validate-vpn.yml`, `validate-infra.yml`, `validate-vms.yml`. For RustFS, the counterpart would be `validate-rustfs.yml`.

### 2. Role-level validation (inside `roles/<service>/`)

- Optional `<service>_verify_health` flag in `defaults/main.yml`.
- `verify`/`validate` tag in `tasks/main.yml` or a separate `tasks/verify.yml` included from `main.yml`.
- Runs during the deployment and can be triggered with `--tags verify`.
- For Windows Docker hosts, delegate to `localhost` and use the Docker CLI or HTTP probes.

Existing examples: `proxy_traefik_verify_health`, `proxy_authelia_verify_health`, `dashboard_homepage_verify_health`.

### 3. Molecule tests (`.molecule/default/verify.yml` in each role)

- Full role-level test with `converge.yml` to apply the role and `verify.yml` to assert outcomes.
- Currently **BLOCKED** (see Testing Status). Until unblocked, playbook validation and role-level verification are the primary quality gates.

## Molecule Configuration

Molecule scenarios are in `.molecule/default/` within each role directory:

- `molecule.yml` - Driver and platform configuration
- `converge.yml` - Ansible playbook to apply the role
- `verify.yml` - Ansible playbook to verify role outcomes

## Testing Status

- **04-001**: ansible-lint configuration & role linting - DONE
- **04-002**: Molecule tests for critical roles - BLOCKED
- **04-003**: Playbook syntax check & dry-run - TODO
- **04-004**: Playbook validation (`validate-*.yml`) for every deploy playbook - TODO
- **04-005**: Role-level `verify`/`validate` tags and `<service>_verify_health` flags for all roles - TODO

## Lessons Learned (copyparty deployment)

### Playbook `include_vars` must load all infrastructure files

Playbooks that use `include_vars` to load infrastructure schemas must load `modes.yml` and `timing.yml` in addition to `ports.yml`, `networks.yml`, `domains.yml`, and `storage.yml`. The client override directory (`levonk/active/02-config/ansible/infrastructure/`) only has `ports.yml`, `networks.yml`, `domains.yml`, `storage.yml` — do NOT try to load `modes.yml` or `timing.yml` from the client directory (they don't exist there).

### `until` expressions cannot use `{{ }}` template delimiters

The `until` clause in Ansible tasks (e.g., `ansible.builtin.uri` retries) does not support `{{ }}` Jinja delimiters. Use a bare expression instead:
```yaml
# ❌ Wrong — Syntax error in expression
until: result.status == {{ infra_http_status_ok }}
# ✅ Correct — bare Jinja expression with filter
until: result.status == (infra_http_status_ok | int)
```

### Cloudflare DNS TTL must be an integer

The `cloudflare-dns` role fails with HTTP 400 if `cloudflare_dns_ttl` is a string (e.g., `"300"`). The Cloudflare API requires TTL as an integer. When setting `cloudflare_dns_ttl` in playbook vars, use `cloudflare_dns_ttl: "{{ infra_dns_ttl | int }}"` or pass it as an integer via `--extra-vars '{"cloudflare_dns_ttl": 300}'`. This affects all playbooks using the `cloudflare-dns` role (deploy-n8n, deploy-copyparty, etc.).

### `project-lint` magic-ipv4 override

The `project-lint` override regex `[A-Za-z,\-]+` does not match digits, so `disable=magic-ipv4` (which contains `4`) is silently ignored. Use `# project-lint: disable` (bare, suppresses all rules on the line) for IPv4 literals like `0.0.0.0` and `127.0.0.1` in Jinja defaults.

## Dependencies

- Depends on: devbox environment
- Requires: molecule, ansible, docker/podman
- Docker images: `debian:bookworm-slim` (matches OCI target)

## Wazuh SIEM/XDR

- **Role**: `security-wazuh` (`roles/security-wazuh/`)
- **Playbook**: `playbooks/deploy-wazuh.yml`
- **Target**: `windows_docker_hosts` group (dtop202311) for the 3-container stack; `cloud_servers` (OCI) for Traefik routing

### Key Deployment Differences

- **Windows Docker modules are broken**: `community.docker` modules fail on Windows because `ansible.module_utils.basic` imports `grp`. Use `delegate_to: localhost` with `DOCKER_HOST: ssh://<windows-wsl>` and `ansible.windows.win_shell` for WSL2-level tasks.
- **WSL2 tuning required**: `vm.max_map_count=262144` must be set in `.wslconfig` and WSL2 restarted before the indexer will start.
- **Indexer single-node discovery**: Do **not** set `cluster.initial_cluster_manager_nodes` when `discovery.type: single-node`. This causes OpenSearch to exit with `IllegalArgumentException`.
- **Certificates via `wazuh-certs-generator`**: The `certs.yml` must list all nodes and static IPs (`wazuh-indexer`, `wazuh-manager`, `wazuh-dashboard`, plus `filebeat` for the manager's Filebeat output). All OpenSearch certs use the `wazuh-*` names; the manager's `ossec.conf` should reference `wazuh-manager.pem` / `wazuh-manager-key.pem`, not `filebeat.pem`.
- **Dashboard volume ownership is critical**: The `wazuh-dashboard` image runs as `wazuh-dashboard` (UID `1000`). The `wazuh-dashboard-config` volume (mounted to `/usr/share/wazuh-dashboard/config`) must be writable by UID `1000` so `opensearch-dashboards-keystore` can create `opensearch_dashboards.keystore`. The `wazuh-dashboard-data` volume (mounted to `/usr/share/wazuh-dashboard/data/wazuh/config`) must also be writable by UID `1000` so `wazuh_app_config.sh` can write `wazuh.yml`.
- **Filebeat config is generated at runtime**: The manager's `1-config-filebeat` s6 script builds `/etc/filebeat/filebeat.yml` from env vars (`INDEXER_USERNAME`, `INDEXER_PASSWORD`, `SSL_CERTIFICATE`, `SSL_KEY`, `SSL_CERTIFICATE_AUTHORITIES`, `FILEBEAT_SSL_VERIFICATION_MODE`). The `wazuh-certs` volume mounts `/etc/ssl/filebeat`.
- **Dashboard health check**: The Ansible role waits for TCP `5601` to open. The `/login` endpoint returns `401` for unauthenticated requests; use `https://wazuh.<base>` (via Traefik/Authelia) to verify the UI is reachable.

## Windows Docker Volume Ownership (UID-mismatch pattern)

**Pattern**: When a container runs as a non-root user (e.g., `--user 1000:1000`) and mounts a Docker volume, the volume is created root-owned by default. The container cannot write to it, causing crash loops with errors like `permission denied` on `.secret_key`, `db.sqlite3`, etc.

**Root cause**: Docker volumes on Docker Desktop for Windows are created with the `local` driver and root ownership. There is no `userns-remap` on Docker Desktop, so UID `1000` inside the container maps to UID `1000` on the host — but the volume directory is owned by root.

**Fix**: Add a `docker run --rm -v <volume>:/data alpine sh -c 'chown -R <uid>:<gid> /data'` task **before** the container deployment task. This is the same pattern used by `security-wazuh` (dashboard volumes) and `search-hister` (data volume).

**Example** (from `roles/search-hister/tasks/deploy-windows.yml`):
```yaml
- name: Fix Hister data volume ownership (UID 1000)
  ansible.builtin.command: >-
    docker run --rm
    -v {{ search_hister_data_volume }}:/data
    alpine sh -c 'chown -R 1000:1000 /data && chmod 755 /data'
  environment:
    DOCKER_HOST: "{{ search_hister_docker_host }}"
  delegate_to: localhost
  changed_when: false
```

**When to apply**: Any Windows Docker role that deploys a container with `--user <non-root-uid>` and a writable volume mount. The chown must run **before** `docker run` for the service container, and should be idempotent (`changed_when: false`).

## Stateful Data Requires Backup Verification

**Any service with a database or persistent stateful data MUST have a backup job
and restore verification.** "Untested backups aren't backups" — a volume mount
or Docker volume is not a backup. If the data would be lost when the container
is recreated or the host dies, it needs a backup.

### When This Applies

A service needs a backup job if it has ANY of:
- A PostgreSQL, MySQL, MariaDB, MongoDB, Redis, or SQLite database
- A Docker volume or bind mount with data that is not regenerable from config
- Time-series data (Prometheus, OpenSearch, InfluxDB)
- Object storage with user-uploaded content (MinIO, RustFS)

A service does NOT need a backup job if:
- All state is config rendered by Ansible (dashboards, proxies, DNS)
- Data is a cache that can be rebuilt (Varnish, SearXNG cache)
- Data is derived from an upstream source (Nix store, blocklists)

### How to Set Up a Backup Job

**For PostgreSQL databases**: use the `devops-restoredrill` role
(`roles/devops-restoredrill/`). It combines pg_dump + restore verification in
one scheduled job. Add the database to `restoredrill_databases` in the client's
group_vars. See `roles/devops-restoredrill/README.md` for the database entry
schema.

**For other databases** (MySQL, Redis, SQLite, OpenSearch): restoredrill is
Postgres-only as of v0.1.0. Use a pg_dump-equivalent (mysqldump, redis-cli
BGSAVE, sqlite3 .backup, opensearch snapshot) + a cron job. Track the
restoredrill roadmap for multi-engine support.

**For file-based state**: use `rsync` or `tar` to a backup directory with
retention. Not all file state needs restore verification — config files are
in Ansible and can be redeployed. Only back up data that cannot be regenerated.

### Cheap Backup Job (Low Space)

The cheapest backup job that still provides verification:

1. **pg_dump -Fc** (custom format) — built-in compression, typically 3-10x
   smaller than the raw database. A 100MB database becomes a 10-30MB dump.
2. **Retention: 7 copies** — keep only the 7 most recent backups. At daily
   cadence, that's one week of history. The `devops-restoredrill` role does
   this automatically (`restoredrill_backup_retention_count: 7`).
3. **Local storage** — store backups on the same host under
   `/opt/localnet/backup/restoredrill/`. No S3, no network, no extra infra.
4. **Daily cadence** — run once at 03:00 (off-peak). The dump + restore drill
   for a small database takes seconds to minutes.
5. **No separate backup tool** — the `devops-restoredrill` role does both the
   dump AND the restore verification in one job. No pg_dump cron + separate
   restoredrill cron.

**Total space for 7 daily backups of a 100MB database**: ~70-210MB (7 x 10-30MB
compressed dumps). For a 1GB database: ~700MB-2GB. This is negligible on any
server with 20GB+ of disk.

**When to go beyond the cheap option**:
- Database > 10GB: consider S3 storage + weekly full + daily incremental
- Compliance requires off-site backups: push to S3 after local dump
- Database > 100GB: restoredrill's ephemeral container model may not fit;
  consider restore-to-dedicated-infra instead

### Adding Backup to a New Service

When adding a new service with a database (Phase 5 of the add-new-service
workflow), also:

1. Check if the database is PostgreSQL — if so, add it to
   `restoredrill_databases` in the client's group_vars
2. Add a storage variable for the backup path in `storage.yml` if needed
3. Document the backup strategy in the service role's README.md
4. For non-Postgres databases, add a cron job or systemd timer for the
   appropriate dump tool

## Monitoring, Alerting & Uptime Are Mandatory Deliverables

Every new service must declare its monitoring integration. The observability
stack (per ADR-202608270001) includes Prometheus (metrics), Grafana
(dashboards), Alertmanager (alert routing with topology-aware inhibition),
Loki (logs), Uptime Kuma (uptime probes), and node_exporter (host metrics).
Even if the stack is not yet deployed, the metadata must be in place.

### What Every Service Must Have

1. **Health check**: A `healthcheck:` block in the `docker_container` task
   and a `{service}_verify_health` boolean default. See `proxy-traefik` or
   `dashboard-homepage` for the pattern.
2. **Catalog monitoring fields**: In `services.yml`, add `metrics_path`,
   `health_endpoint`, and `alert_labels` to the service entry. For pipeline
   services, also add `pipeline` and `pipeline_stage`.
3. **Metrics endpoint** (if applicable): If the service exposes Prometheus
   metrics, declare the metrics port in `ports.yml` and set `metrics_path`
   and `metrics_port` in `services.yml`.
4. **Role README documentation**: A "Monitoring" section describing the
   metrics endpoint, health check, pipeline classification, and alert
   behavior.

### Pipeline Services

Services that are part of a defined pipeline (AI, DNS, Web, VPN per
ADR-202608270001) must also have:

- `pipeline` and `pipeline_stage` fields in `services.yml`
- `alert_labels` matching the ADR label schema (`pipeline`, `stage`,
  `service`) so Alertmanager inhibition rules apply correctly
- Per-node alert rules in the `monitoring-alertmanager` role (when deployed)

### Uptime Monitoring

When the `monitoring-uptime-kuma` role is deployed, add the service to
`monitoring_uptime_kuma_monitors` in the client's group_vars. For public
services, probe the Traefik domain. For internal services, probe the
container hostname:port directly.

### node_exporter Textfile Collector

Services that produce custom metrics (like `devops-restoredrill`) should
write to the node_exporter textfile directory
(`/var/lib/node_exporter/textfile/`) so the metrics are scraped by
node_exporter without a dedicated scrape config. See the `devops-restoredrill`
role for the pattern.

## JIT Index

- Ansible Lint Troubleshooting: [`internal-docs/troubleshooting/ansible-lint.md`](../../../internal-docs/troubleshooting/ansible-lint.md) — role naming convention, yamllint config crashes, pre-existing violations
- Windows Development: [`internal-docs/windows-development.md`](../../../internal-docs/windows-development.md) — Windows module gaps, cross-platform role patterns, win_shell for blockinfile
- Root AGENTS.md: [`../../../AGENTS.md`](../../../AGENTS.md) — environment setup, vault, deployment workflow, architectural invariants
- Backup Verification: [`roles/devops-restoredrill/README.md`](roles/devops-restoredrill/README.md) — restoredrill role for PostgreSQL backup + restore verification
- Observability Strategy: [`shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`](../../08-docs/adr/adr-202608270001-pipeline-observability-strategy.md) — ADR for topology-aware monitoring with Alertmanager inhibition
- Developer Guide: [`../../../.agents/knowledge/developer.md`](../../../.agents/knowledge/developer.md) — key directories, patterns, boundaries, known gotchas

## Windows Docker Desktop Gotchas

### Insecure Registry Configuration

Docker Desktop on Windows does **not** read `~/.docker/daemon.json` for daemon configuration. The `daemon.json` in the user's `.docker` directory is for the Docker CLI, not for the daemon. To configure insecure registries:

1. Open Docker Desktop → Settings → Docker Engine → add `"insecure-registries": ["100.90.22.85:5000"]`
2. Apply & Restart from the UI
3. Docker Desktop cannot be restarted via SSH — it requires an interactive desktop session

### proxy_traefik_windows Role Dependencies

The `proxy_traefik_windows` role renders dynamic config templates for all nl-region services. The Hister template (`hister-nl.yml.j2`) uses `search_hister_*` variables directly (not the `proxy_traefik_windows_hister_*` wrapper variables). Any playbook that includes `proxy_traefik_windows` must also load the `search-hister` role defaults:

```yaml
- name: "Load search-hister role defaults (required by proxy_traefik_windows hister template)"
  ansible.builtin.include_vars:
    file: "{{ playbook_dir }}/../roles/search-hister/defaults/main.yml"
```

### Container Healthcheck Commands

Not all container images include `wget`. Stirling-PDF (and other Java/Alpine-based images) may only have `curl`. Always verify the healthcheck command is available in the target image before deploying. Use `curl -sf` as a safer default than `wget -qO-`.

### DOCKER_CONFIG on `docker pull` — macOS Keychain Unlock Modal

**MANDATORY**: Every `docker pull` task that uses `delegate_to: localhost` with `DOCKER_HOST: ssh://...` MUST set `DOCKER_CONFIG` to a credential-free config directory. Without this, the Docker CLI invokes `docker-credential-osxkeychain` (configured via `credsStore: osxkeychain` in `~/.docker/config.json`) on every pull — including pulls of **public images** — which triggers the macOS "unlock keychain" modal when the login keychain is locked (after sleep, screen lock, or reboot).

**Setup** (one-time, on the control machine):
```bash
mkdir -p ~/.docker-no-creds
printf '{}\n' > ~/.docker-no-creds/config.json
chmod 600 ~/.docker-no-creds/config.json
```

**Required pattern** for all `docker pull` tasks in Windows-deploy roles:
```yaml
- name: Pull <image>
  ansible.builtin.command: "docker pull {{ some_image }}"
  environment:
    DOCKER_HOST: "{{ some_docker_host }}"
    DOCKER_CONFIG: "{{ lookup('env', 'HOME') }}/.docker-no-creds"
  delegate_to: localhost
  changed_when: true
  tags: ["deploy", "pull"]
```

**Why not remove `credsStore` globally?** The default `~/.docker/config.json` uses `osxkeychain` for private registry auth (Docker Hub, ghcr.io, etc.). Removing it would break `docker login` flows. The `DOCKER_CONFIG` override is surgical — it only applies to the Ansible-managed pull tasks, leaving interactive `docker pull`/`docker login` unaffected.

**Why not set `DOCKER_CONFIG` on non-pull tasks?** `docker run` with a missing image will auto-pull, but in these roles `docker pull` is always a separate preceding task. If a role ever uses `docker run` without a preceding `docker pull`, add `DOCKER_CONFIG` to that task too.

### Image Transfer to Windows Docker Hosts

When the local registry (`100.90.22.85:5000`) is not configured as insecure on the Windows Docker host, images can be transferred via `docker save | gzip` + `scp` + `docker load`:

```bash
docker save <image> | gzip > /tmp/image.tar.gz
scp /tmp/image.tar.gz 'dtop202311.tale-grouper.ts.net:C:/Users/ansible/image.tar.gz'
ssh dtop202311.tale-grouper.ts.net 'docker load -i C:/Users/ansible/image.tar.gz'
```
