# QM Service Research

## Overview

QM (https://github.com/yc-software/qm) is a multiplayer agent harness for work.
It provides each employee with an isolated workspace, scoped memory, files,
keychain, permissions, crons, web apps, and a durable sandbox. It supports
Slack and web UI surfaces.

## Deployment Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Target machine | dtop202311 (Windows, WSL Docker) | User request — deploy on Windows machine via WSL Docker |
| Deploy model | Pre-built ghcr.io images + qm init | QM distributes signed pre-built images; no need to build from source |
| Slack plugin | Disabled (web UI only) | User choice — simpler secret footprint |
| Domain | qm.levonk.com | User choice — standard subdomain pattern |
| Sandbox backend | SANDBOX_BACKEND=local (dev-only) | User choice — fully self-hosted, no Fly.io dependency |
| Windows pattern | delegate_to:localhost + community.docker + DOCKER_HOST=ssh:// | User choice — uses community.docker modules per AGENTS.md |
| Postgres | Per-service container (postgres:16) | Follows ai-paperclip pattern |

## Architecture

```
                    Traefik (qm.levonk.com)
                         |
                    web-ui container (:8082)
                         |
                    core container (:8080)
                    /         \
           Postgres (:5432)   Sandbox (local Docker)
```

### Containers (from `qm plan`)

1. **Postgres**: `qm-levonk-pg`
   - Image: `postgres:16`
   - Volume: `qm-levonk-pgdata`
   - Port: 5432 (container)
   - Env: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD

2. **Core**: `qm-levonk-core`
   - Image: `ghcr.io/yc-software/qm/core@sha256:bee03e7f22719dfe76ea2c83bb65db2bdefd55b714eae4014007033800bdb5ab`
   - Port: 8080 (container)
   - Env: CORE_SIGNING_SECRET, ORG_ID, PUBLIC_WEB_URL, WEB_UI_PUBLIC_URL, PORT,
     DATA_DIR, SESSION_STORE, RUN_STORE, DATABASE_URL, MODEL_PROVIDER,
     DEPLOYMENT_LAYER, FLY_SANDBOX_APP_NAME, FLY_BASE_IMAGE, HARNESS,
     SANDBOX_BACKEND, ANTHROPIC_API_KEY, CAPABILITY_SECRET,
     CONNECTOR_SECRET_KEY, PORTAL_IDENTITY_SECRET, PUBLIC_API_URL,
     SKILL_SIGNING_SECRET
   - Layer mount: sandbox directory → /layer (skills, tools)

3. **Web-UI**: `qm-levonk-web-ui`
   - Image: `ghcr.io/yc-software/qm/web-ui@sha256:f037834fd726bcff220245665ef46accb10b476331006a85c59defbde1635e52`
   - Port: 8082 (container)
   - Env: CORE_SIGNING_SECRET, PORT, CORE_API_URL, CORE_ORG_ID,
     WEB_UI_PUBLIC_URL, PORTAL_IDENTITY_SECRET

### Network

- `qm-levonk` (custom Docker network for inter-container communication)
- `traefik-network` (for Traefik routing to web-ui)

### Sandbox Image

- Built locally with `qm sandbox build`
- Base: `ghcr.io/yc-software/qm/sandbox-base@sha256:52cb44a6e9d166da20638c8ce55e3f423384f5557eba49915684cb8ed16e5873`
- Local tag: `levonk-sandbox:local`
- Must be pinned by digest in qm.config.jsonc
- Needs to be available on the target host's Docker daemon

## Configuration (qm.config.jsonc)

```jsonc
{
  "contract": 1,
  "orgId": "levonk",
  "publicUrl": "https://qm.levonk.com",
  "target": "docker",
  "modelProvider": "anthropic",
  "services": ["core", "web-ui"],
  "plugins": [],
  "skills": [],
  "env": { "core": { "HARNESS": "pi", "SANDBOX_BACKEND": "local" } },
  "sandbox": { "app": "levonk-sandboxes", "image": "levonk-sandbox:local@sha256:..." }
}
```

## Secrets (vault)

| Variable | Purpose | Generation |
|----------|---------|------------|
| `vault_qm_anthropic_api_key` | Anthropic API key for base model | User-provided |
| `vault_qm_capability_secret` | Signing key for scoped agent capabilities | `openssl rand -hex 32` |
| `vault_qm_connector_secret_key` | Encryption key for connector credentials | `openssl rand -hex 32` |
| `vault_qm_core_signing_secret` | HMAC key shared by core and web-ui | `openssl rand -hex 32` |
| `vault_qm_portal_identity_secret` | Signing key for portal user identity | `openssl rand -hex 32` |
| `vault_qm_skill_signing_secret` | Signing key for reviewed skills | `openssl rand -hex 32` |
| `vault_qm_postgres_password` | Postgres database password | `openssl rand -hex 32` |

## Infrastructure Variables

### Ports
- `infra_port_ai_qm_core_host`: "3104" → container 8080
- `infra_port_ai_qm_web_host`: "3105" → container 8082
- `infra_port_ai_qm_postgres_host`: "5437" → container 5432

### Domain
- `infra_domain_ai_qm`: "qm.levonk.com"

### Network
- `infra_network_ai_qm_network_name`: "qm-levonk"
- `infra_network_ip_qm`: "172.31.0.22"

### Storage
- `infra_storage_qm_postgres_volume`: "localnet-qm-postgres-data-volume"
- `infra_storage_qm_layer_volume`: "localnet-qm-layer-volume"

## Target Host: dtop202311 (Windows/WSL)

### Connection Pattern

The repo uses `delegate_to: localhost` with `DOCKER_HOST: ssh://ansible@dtop202311.tale-grouper.ts.net`
for Windows/WSL Docker deployment. This runs community.docker modules on the
Ansible controller (macOS) while connecting to the remote Docker daemon via SSH.

```yaml
# In role tasks
- name: Deploy qm container
  community.docker.docker_container:
    name: "{{ qm_core_container_name }}"
    image: "{{ qm_core_image_name }}:{{ qm_core_image_tag }}"
    state: started
    # ... config ...
  delegate_to: localhost
  vars:
    ansible_docker_host: "ssh://ansible@dtop202311.tale-grouper.ts.net"
```

### WSL Setup

- WSL2 is enabled on dtop202311 (bootstrap playbook installs with --no-distribution)
- Docker Desktop runs in its own WSL2 distribution
- Docker daemon is accessed via Windows SSH (port 22) + Docker CLI proxy
- No direct WSL SSH needed — the SSH-tunneled Docker pattern works through Windows SSH
- community.docker modules fail when run directly on Windows (grp import error)
- delegate_to:localhost avoids this by running modules on the Ansible controller

### Existing Windows-Deployed Roles (pattern reference)

- security-wazuh
- vpn-nordvpn-windows
- vpn-tor-windows
- storage-rustfs
- p2p-freenet
- tools-croc-relay
- career-jobops

## Implementation Plan

### Role: `ai-qm`

Based on `ai-paperclip` (custom image + Postgres + Traefik labels).

**Key differences from ai-paperclip:**
1. Uses upstream ghcr.io images (not locally-built)
2. Two service containers (core + web-ui) instead of one
3. Sandbox image needs to be built and available on target
4. Windows/WSL deployment (delegate_to:localhost + DOCKER_HOST)
5. qm.config.jsonc and sandbox layer need to be synced to target

### Build Pipeline

- **Sandbox image**: Build with `qm sandbox build` on the Ansible controller,
  push to local registry (100.90.22.85:5000), pull on target during deployment.
  OR build directly on target if Node.js 24+ is available.
- **Core/Web-UI images**: Pull from ghcr.io (upstream pre-built)

### Deployment Steps

1. Add infrastructure variables (ports, domain, network, storage)
2. Add vault secrets (via user handoff)
3. Create `ai-qm` role with:
   - defaults/main.yml (all config variables)
   - tasks/main.yml (Postgres, core, web-ui containers with delegate_to)
   - handlers/main.yml (restart handlers)
   - templates/qm.config.jsonc.j2 (config template)
4. Add Traefik routing (Docker labels on web-ui container)
5. Add DNS record (qm.levonk.com CNAME → dtop202311 Tailscale FQDN)
6. Add service catalog entry
7. Create playbook
8. Build sandbox image and push to registry
9. Deploy and verify

## Limitations

1. **SANDBOX_BACKEND=local is dev-only**: QM's local sandbox backend lacks
   production-grade isolation and egress controls. Acceptable for evaluation
   but not for production use with untrusted users.
2. **No health check endpoint documented**: QM does not document a specific
   health check path. Will use TCP port check as fallback.
3. **Sandbox image platform**: The sandbox-base image is linux/amd64 only.
   The target (dtop202311 WSL) runs amd64, so this is compatible.
4. **qm CLI required for sandbox build**: Building the sandbox image requires
   Node.js 24+ and the `@yc-software/qm` npm package.
5. **Image digest pinning**: QM requires sandbox images to be pinned by
   SHA-256 digest. The deployment must record the digest after building.

## References

- Source repo: https://github.com/yc-software/qm
- CLI docs: https://raw.githubusercontent.com/yc-software/qm/main/cli/README.md
- Deployment guide: https://raw.githubusercontent.com/yc-software/qm/main/docs/deploy-directory.md
- Getting started: https://raw.githubusercontent.com/yc-software/qm/main/docs/getting-started.md
- Security model: https://github.com/yc-software/qm/blob/main/SECURITY.md
- Generated deployment dir: /tmp/qm-deployment/ (from `qm init --org levonk --target docker`)
