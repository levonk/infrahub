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

## DNS Architecture (Two-Layer)

The shared roles provide a two-layer DNS architecture for Tailscale-attached hosts. Clients opt in by setting Tailscale FQDN variables in their `infrastructure/domains.yml` and per-host `cloudflare_ddns_hostname` in their inventory.

### Layer 1: CNAME → Tailscale FQDN (Primary)

**Role**: `cloudflare-dns`  
**Playbook**: `playbooks/configure-cloudflare-dns.yml`

Service domains (`*.levonk.com`) are CNAMEs to Tailscale FQDNs (`*.tale-grouper.ts.net`). This decouples Cloudflare DNS from ephemeral Tailscale IPs — if Tailscale reassigns the IP, only Tailscale's internal DNS updates. See AGENTS.md (root) → Architectural Invariant #9 for the full rule.

### Layer 2: DDNS → Public IP (Fallback)

**Role**: `cloudflare-ddns`  
**Playbook**: `playbooks/deploy-cloudflare-ddns.yml`

A lightweight container on each host updates an A record (`{hostname}.mach.{domain}`) with the host's **public IP** every 5 minutes. This provides a non-Tailscale fallback — if Tailscale MagicDNS is down but the host has internet, the `*.mach.{domain}` records still resolve. See `roles/cloudflare-ddns/README.md` for details.

### Variables (shared defaults, overridden by client)

| Variable | Shared default | Client override |
|----------|---------------|-----------------|
| `infra_tailscale_tailnet` | `example.ts.net` | `tale-grouper.ts.net` |
| `infra_tailscale_fqdn_cloud_server` | `{{ infra_tailscale_tailnet }}` | `oci.tale-grouper.ts.net` |
| `infra_tailscale_fqdn_inference_host` | (none) | `kckinai.tale-grouper.ts.net` |
| `cloudflare_ddns_hostname` | (none — set per-host) | `"oci"`, `"kckinai"` |

### Clients Using This Feature

- **levonk**: `oci.mach.levonk.com` → public IP, `kckinai.mach.levonk.com` → public IP. See `levonk/AGENTS.md` → "DNS & DDNS Rollout" for the client-specific deployment status.

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

## Molecule Configuration

Molecule scenarios are in `.molecule/default/` within each role directory:

- `molecule.yml` - Driver and platform configuration
- `converge.yml` - Ansible playbook to apply the role
- `verify.yml` - Ansible playbook to verify role outcomes

## Testing Status

- **04-001**: ansible-lint configuration & role linting - DONE
- **04-002**: Molecule tests for critical roles - BLOCKED
- **04-003**: Playbook syntax check & dry-run - TODO

## Dependencies

- Depends on: devbox environment
- Requires: molecule, ansible, docker/podman
- Docker images: `debian:bookworm-slim` (matches OCI target)
