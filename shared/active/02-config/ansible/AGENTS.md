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

- `diagrams/proxy/complete-web-proxy-chain.mmd` — full architecture diagram
- `requirements/proxy/mitm-ca-distribution.md` — CA certificate strategy
- `requirements/proxy/caching-strategy.md` — Varnish vs Squid decision
- `requirements/proxy/egress-routing.md` — Gost egress multiplexer config

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

## JIT Index

- Ansible Lint Troubleshooting: [`internal-docs/troubleshooting/ansible-lint.md`](../../../internal-docs/troubleshooting/ansible-lint.md) — role naming convention, yamllint config crashes, pre-existing violations
- Windows Development: [`internal-docs/windows-development.md`](../../../internal-docs/windows-development.md) — Windows module gaps, cross-platform role patterns, win_shell for blockinfile
- Root AGENTS.md: [`../../../AGENTS.md`](../../../AGENTS.md) — environment setup, vault, deployment workflow, architectural invariants
- Developer Guide: [`../../../.agents/knowledge/developer.md`](../../../.agents/knowledge/developer.md) — key directories, patterns, boundaries, known gotchas
