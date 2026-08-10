---
workflow: "Add a Sandboxed CLI Tool to Infrahub"
slug: "infrahub-add-sandboxed-cli-tool"
description: "Phase-by-phase implementation guide for adding a sandboxed CLI tool: egress profile, iron-proxy allowlist, just recipe, tool catalog entry. Covers the two-layer architecture from ADR-202608051501 — Ansible-managed persistent proxy + just recipe for ephemeral CLI invocations."
use: "When adding a new CLI tool (sherlock, subfinder, recon tools, scrapers) that needs sandboxed egress control via iron-proxy. Not for server services — use infrahub-add-new-service.md for those."
date:
  created: "2026-08-05"
  updated: "2026-08-05"
  last-used: ""
see-also:
  - file: "infrahub-add-new-service.md"
    relationship: "sibling"
    description: "Implementation guide for adding server services (long-running containers with Traefik routing, healthchecks, volumes). Use that workflow for services, this one for ephemeral CLI tools."
  - file: "infrahub-add-new-service-orchestrator.md"
    relationship: "sibling"
    description: "Orchestrator for the service workflow. No orchestrator exists for CLI tools — the process is simpler and does not require PRD/task breakdown."
  - adr: "adr-202608051501-sandboxed-cli-egress"
    relationship: "decision-record"
    description: "ADR that defines the two-layer sandboxed CLI egress architecture: iron-proxy as default-deny egress firewall, MITM mode with system trust store CA, GET + HEAD + scoped POSTs method policy, profile-based allowlists, selectable deployment target (Mac or OCI)."
  - skill: "infrahub-container-deploy"
    relationship: "implementation"
    description: "Infrahub-specific overlay for container deployment: userns-remap UID 100000, vault handoff, infra_ variable naming, functional-group role naming, local registry. Used when deploying the iron-proxy instance (Phase 3)."
---

# Workflow: Add a Sandboxed CLI Tool to Infrahub

This workflow guides an agent through adding a sandboxed CLI tool end-to-end:
egress profile selection, iron-proxy allowlist configuration, `just` recipe
creation, and tool catalog registration. Follow every phase in order. Do not
skip phases.

## What This Workflow Is For

**CLI tools** are ephemeral, interactive container invocations of untrusted or
semi-trusted tools. They are not server services. They run, produce output to
stdout, and exit. Examples:

- `sherlock/sherlock` — username enumeration across social networks
- `projectdiscovery/subfinder` — subdomain discovery
- Web scrapers, recon tools, OSINT utilities
- Any third-party CLI that makes outbound network calls

**For server services** (long-running containers with Traefik routing,
healthchecks, persistent volumes), use
[`infrahub-add-new-service.md`](infrahub-add-new-service.md) instead.

## Prerequisites

1. Read the root [`AGENTS.md`](../../AGENTS.md) — especially "Architectural
   Invariants" and "Host Mutation Policy" (the throwaway-container carve-out)
2. Read the [Developer Guide](../knowledge/developer.md) — especially the
   critical-files tree and boundaries
3. Read
   [ADR-202608051501: Sandboxed CLI Container Egress Control](../../shared/active/08-docs/adr/adr-202608051501-sandboxed-cli-egress.md)
   — the architectural decision that defines this workflow's two-layer design
4. Read [`shared/active/02-config/ansible/AGENTS.md`](../../shared/active/02-config/ansible/AGENTS.md)
   — container module rules, port conflict checking
5. Know the tool name, upstream Docker image, what hosts it needs to reach, and
   what HTTP methods it uses
6. Know the tool's **primary source repository URL** (GitHub/GitLab repo). This
   is required for the `source_repo` field in `tools.yml` (Phase 5).

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│  Control machine (Mac) or OCI cloud server                  │
│                                                              │
│  ┌──────────────┐    ┌───────────────────────────┐          │
│  │  iron-proxy  │◄───│  Ephemeral CLI container   │          │
│  │  (persistent,│    │  (sherlock, subfinder...)  │          │
│  │   Ansible-   │    │  --rm -it --read-only      │          │
│  │   managed)   │    │  --cap-drop ALL             │          │
│  │              │    │  HTTP_PROXY=iron-proxy:80   │          │
│  │  allowlist:  │    └───────────────────────────┘          │
│  │  GET+HEAD+   │                                           │
│  │  scoped POST │                                           │
│  └──────┬───────┘                                           │
│         │ default-deny egress                                │
│         ▼                                                    │
│       Internet (only allowlisted hosts)                      │
└─────────────────────────────────────────────────────────────┘
```

**Two layers** (from ADR-202608051501):

1. **Ansible-managed persistent proxy** — `community.docker.docker_container`
   deploys iron-proxy as a long-running service. This is a real deployment,
   governed by the Deployment Workflow Rule.
2. **`just` recipe for ephemeral CLI invocations** — `docker run --rm -it` for
   the CLI tool. This is a throwaway container, carved out of the Host Mutation
   Policy.

## Decision: New Profile vs Existing Profile

Before starting, determine whether the tool fits an existing egress profile or
needs a new one.

**Profiles** are named allowlist configurations (e.g., `osint`, `recon`,
`scrape`). Each profile deploys a separate iron-proxy instance on a dedicated
Docker network with its own allowlist. See ADR-202608051501 → "Profile-Based
Allowlist for a Class of Tools".

- **Existing profile covers the tool**: The tool's required hosts are already in
  an existing profile's allowlist. Skip Phase 1-3, go directly to Phase 4 (just
  recipe) and Phase 5 (catalog entry).
- **New profile needed**: The tool needs hosts not in any existing profile.
  Complete all phases.

---

## Phase 1: Shared Infrastructure Schemas (New Profile Only)

Add the variable **schema** (neutral defaults) for the new profile's iron-proxy
instance to the shared infrastructure files.

### 1a. Ports — `shared/active/02-config/ansible/infrastructure/ports.yml`

Add port variables following the naming convention
`infra_port_sandbox_{profile}_{CONTEXT}`:

```yaml
# Sandboxed CLI Proxy — {Profile Name} profile
infra_port_sandbox_{profile}_http: "{http_port}"
infra_port_sandbox_{profile}_https: "{https_port}"
infra_port_sandbox_{profile}_dns: "{dns_port}"
```

**Check for conflicts first**: scan this file AND
`levonk/active/02-config/ansible/infrastructure/ports.yml` for the ports you
want. Also check `docker ps` on the target host. If conflicts, stop and surface
to user.

### 1b. Networks — `shared/active/02-config/ansible/infrastructure/networks.yml`

Each profile gets its own Docker network for isolation:

```yaml
# Sandboxed CLI Proxy — {Profile Name} profile
infra_network_sandbox_{profile}_name: "sandbox-{profile}-net"
infra_network_sandbox_{profile}_subnet: "{subnet_cidr}"
infra_network_sandbox_{profile}_gateway: "{gateway_ip}"
infra_network_sandbox_{profile}_proxy_ip: "{proxy_ip}"
```

**Subnet allocation**: Use `172.40.0.0/16` and up for sandbox networks. Check
existing sandbox profiles to avoid subnet collisions. Each profile gets a
`/16` subnet.

### 1c. Storage — `shared/active/02-config/ansible/infrastructure/storage.yml`

The iron-proxy CA certificate directory:

```yaml
# Sandboxed CLI Proxy — CA certificate storage
infra_storage_sandbox_ca_dir: "/opt/sandbox-cli"
```

This is shared across all profiles — the CA is the same for every iron-proxy
instance. Only add this once, on the first profile.

---

## Phase 2: Client Infrastructure Values (New Profile Only)

Override the shared defaults with client-specific values in
`levonk/active/02-config/ansible/infrastructure/`.

**Only add overrides here if the client value differs from the shared default.**
If the shared default works, don't duplicate it.

### 2a. Ports — `levonk/active/02-config/ansible/infrastructure/ports.yml`

```yaml
# Sandboxed CLI Proxy — {Profile Name} (client-specific override)
infra_port_sandbox_{profile}_http: "{port}"
infra_port_sandbox_{profile}_https: "{port}"
infra_port_sandbox_{profile}_dns: "{port}"
```

### 2b. Networks — `levonk/active/02-config/ansible/infrastructure/networks.yml`

```yaml
# Sandboxed CLI Proxy — {Profile Name} (client-specific)
infra_network_sandbox_{profile}_name: "sandbox-{profile}-net"
infra_network_sandbox_{profile}_subnet: "{subnet}"
infra_network_sandbox_{profile}_gateway: "{gateway}"
infra_network_sandbox_{profile}_proxy_ip: "{proxy_ip}"
```

---

## Phase 3: Allowlist Configuration (New Profile Only)

Define the egress policy for the new profile in client group_vars.

### 3a. Add profile to sandbox_cli_proxy_profiles

File: `levonk/active/02-config/ansible/group_vars/sandbox_proxy_hosts.yml`

```yaml
sandbox_cli_proxy_profiles:
  - name: "{profile}"
    network: "{{ infra_network_sandbox_{profile}_name }}"
    subnet: "{{ infra_network_sandbox_{profile}_subnet }}"
    gateway: "{{ infra_network_sandbox_{profile}_gateway }}"
    proxy_ip: "{{ infra_network_sandbox_{profile}_proxy_ip }}"
    http_port: "{{ infra_port_sandbox_{profile}_http }}"
    https_port: "{{ infra_port_sandbox_{profile}_https }}"
    dns_port: "{{ infra_port_sandbox_{profile}_dns }}"
    allowlist_rules:
      # {Host Category} — GET + HEAD only
      - host: "*.example.com"
        methods: ["GET", "HEAD"]
        paths: ["/*"]
      # {Host Category} — GET + HEAD + scoped POST
      - host: "api.example.com"
        methods: ["GET", "HEAD", "POST"]
        paths: ["/v1/search", "/v1/query"]
```

### 3b. Allowlist rule structure

Each rule in `allowlist_rules` has:

| Field | Type | Description |
|-------|------|-------------|
| `host` | string | Domain glob (e.g., `*.google.com`, `api.github.com`) |
| `methods` | list | Allowed HTTP methods (e.g., `["GET", "HEAD"]`) |
| `paths` | list | Allowed path globs (e.g., `["/*"]`, `["/v1/messages"]`) |

**Method policy** (from ADR-202608051501):
- Default: `["GET", "HEAD"]` for all hosts
- Add scoped POSTs per-host only where the tool requires them
- The allowlist is default-deny: anything not matched returns 403

### 3c. Deploy the proxy

```bash
# Deploy the sandbox-cli-proxy role with the new profile
devbox run -- rtk ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/macos-hosts.yml \
  shared/active/02-config/ansible/playbooks/deploy-sandbox-proxy.yml \
  --vault-password-file ~/.ansible/vault_password
```

If deploying to OCI instead of (or in addition to) Mac:

```bash
devbox run -- rtk ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-sandbox-proxy.yml \
  --vault-password-file ~/.ansible/vault_password
```

### 3d. Verify the proxy is running

```bash
# Check the iron-proxy container for this profile
docker ps | grep "sandbox-{profile}"

# Check the allowlist is enforced (should get 403 for non-allowlisted host)
curl -x http://localhost:{http_port} http://non-allowlisted.example.com

# Check the allowlist allows an expected host
curl -x http://localhost:{http_port} http://allowlisted.example.com
```

---

## Phase 4: Create the `just` Recipe

The `just` recipe is the primary interface for running the sandboxed CLI tool.
It is NOT an Ansible role — it is a throwaway container invocation that fits
the Host Mutation Policy carve-out for "operations inside a throwaway container
that does not touch host or app state."

### 4a. Add the recipe to the justfile

File: `justfile` (repo root)

```makefile
# Run {tool_name} in a sandboxed container with egress control.
# Usage: just sandbox-{tool} {args}
sandbox-{tool} *args:
    #!/usr/bin/env bash
    set -euo pipefail
    source {{ justfile_directory() }}/.sandbox-env
    docker run --rm -i \
      --network "${SANDBOX_{PROFILE^^}_NETWORK}" \
      --read-only \
      --tmpfs /tmp:rw,size=64m \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --user 1000:1000 \
      -e HTTP_PROXY="http://${SANDBOX_{PROFILE^^}_PROXY_HOST}:80" \
      -e HTTPS_PROXY="http://${SANDBOX_{PROFILE^^}_PROXY_HOST}:443" \
      -e REQUESTS_CA_BUNDLE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -e SSL_CERT_FILE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -v "${SANDBOX_{PROFILE^^}_CA_HOST_PATH}:${SANDBOX_CA_CERT_SYSTEM_PATH}:ro" \
      --entrypoint sh \
      "{tool_image}" \
      -c "update-ca-certificates 2>/dev/null || true; exec {tool_command} {{ args }}"
```

**Recipe variables** (replace with actual values):

| Variable | Description | Example |
|----------|-------------|---------|
| `{tool}` | URL-friendly tool name for the recipe | `sherlock` |
| `{tool_image}` | Upstream Docker image | `sherlock/sherlock` |
| `{tool_command}` | The command to exec inside the container | `sherlock` |
| `{PROFILE}` | The egress profile name (uppercase for env vars) | `OSINT` |

### 4b. The `.sandbox-env` file

The `.sandbox-env` file is generated by the `sandbox-cli-proxy` Ansible role
during deployment. It contains resolved variable values for each profile:

```bash
# Generated by Ansible — do not edit
SANDBOX_OSINT_NETWORK=sandbox-osint-net
SANDBOX_OSINT_PROXY_HOST=sandbox-iron-proxy-osint
SANDBOX_OSINT_CA_HOST_PATH=/opt/sandbox-cli/ca/ca.crt
SANDBOX_CA_CERT_CONTAINER_PATH=/etc/ssl/certs/sandbox-ca.crt
SANDBOX_CA_CERT_SYSTEM_PATH=/usr/local/share/ca-certificates/sandbox-ca.crt
```

If the file does not exist, the proxy has not been deployed yet. Run Phase 3c
first.

### 4c. CA certificate handling

The recipe mounts the iron-proxy CA certificate into the container's system CA
directory and runs `update-ca-certificates` on entry. This ensures all tools
that use the system trust store (Go binaries, curl, wget, system Python) trust
the MITM proxy.

**For images without `update-ca-certificates`**: The `2>/dev/null || true`
fallback means the recipe still works — `REQUESTS_CA_BUNDLE` and
`SSL_CERT_FILE` env vars are set as a fallback for Python tools and other
env-var-aware libraries.

**For images without `sh`**: Use a custom wrapper image or a different
entrypoint strategy. Document this in the tool's catalog entry (Phase 5).

### 4d. Test the recipe

```bash
# Run the tool through the sandbox
devbox run -- just sandbox-{tool} {test_args}

# Verify egress is restricted (should fail with 403)
# Add a test that tries to reach a non-allowlisted host
```

---

## Phase 5: Register in Tool Catalog

Add the tool entry to the tool catalog metadata file, then regenerate the
catalog.

### 5a. Add entry to tools.yml

File: `shared/active/02-config/ansible/infrastructure/tools.yml`

```yaml
# {Tool Display Name}
- name: "{Tool Display Name}"
  image: "{tool_image}"
  profile: "{profile}"
  description: "{one-line description}"
  source_repo: "{primary source repo URL}"
  egress:
    hosts: ["{host patterns}"]
    methods: ["GET", "HEAD"]
  recipe: "sandbox-{tool}"
  notes: "{optional notes about CA handling, entrypoint quirks, etc.}"
```

**`source_repo` field (REQUIRED)**:

Every tool entry MUST include `source_repo` — a link to the tool's primary
source repository. This ensures all `TOOLS.md` entries are traceable to their
upstream source.

- **Open-source tools**: Use the GitHub/GitLab repo URL
  (e.g., `https://github.com/sherlock-project/sherlock`)
- **Commercial/no-source tools**: Use the product page or official website

**`egress` field**: Documents the egress policy the tool operates under. This
is for human reference — the actual enforcement is in the iron-proxy allowlist
(Phase 3a). The `hosts` list shows the domain patterns, and `methods` shows
the allowed HTTP methods.

**`recipe` field**: The `just` recipe name (without `just` prefix). This lets
users find the command to run the tool from the catalog.

### 5b. Regenerate the tool catalog

```bash
# 1. Regenerate levonk/TOOLS.md (client-specific)
devbox run -- just generate-tool-catalog

# 2. Regenerate infrahub/TOOLS.md (repo-root, shared defaults only)
devbox run -- just generate-tool-catalog-shared

# Or run both at once:
devbox run -- just generate-tool-catalog-all
```

**Two catalogs, two audiences** (same pattern as SERVICES.md):

| Catalog | Path | Audience | Contents |
|---------|------|----------|----------|
| Client | `levonk/TOOLS.md` | Client submodule (private) | Deployed profiles, client-specific ports |
| Repo-root | `infrahub/TOOLS.md` | Parent repo (shared) | Default ports, profile definitions (no client deployment info) |

### 5c. Verify the catalog entry

Check that the tool appears in the generated `TOOLS.md`:

```bash
grep "{Tool Display Name}" levonk/TOOLS.md
grep "{Tool Display Name}" infrahub/TOOLS.md
```

---

## Phase 6: Documentation

### 6a. Update the tool's README (if applicable)

If the tool has a service directory under
`shared/active/03-container/services/`, add a README.md documenting:

- What the tool does
- The egress profile it uses
- The `just` recipe to run it
- Any CA certificate or entrypoint quirks

### 6b. Update AGENTS.md (if learnings emerged)

If the tool revealed a new pattern, gotcha, or convention that future agents
should know about, add it to the root `AGENTS.md` or the relevant sub-AGENTS.md.

---

## Hand Back to User

After Phase 6 and the checklist below passes, the tool is ready to use. Unlike
the service workflow, there is no orchestrator to hand back to — CLI tools are
simpler and do not require the full research/PRD/deploy/verify pipeline.

**Provide the user with:**

```markdown
**Sandboxed CLI Tool Added: {Tool Display Name}**

**Recipe:** `just sandbox-{tool} {args}`
**Egress profile:** {profile}
**Allowlisted hosts:** {host patterns}
**Allowed methods:** GET + HEAD {+ scoped POSTs if applicable}

**Testing:**
- Run: `devbox run -- just sandbox-{tool} {test_args}`
- Verify egress: check iron-proxy logs for 403s on non-allowlisted hosts
- Verify filesystem: confirm no host filesystem access outside stdin/stdout

**Catalog:**
- Added to `shared/active/02-config/ansible/infrastructure/tools.yml`
- Regenerated `levonk/TOOLS.md` and `infrahub/TOOLS.md`
```

---

## Checklist (Run Through Before Completing)

- [ ] **No hardcoded values**: All ports, networks, IPs reference `infra_*`
      variables
- [ ] **No client data in shared/**: Role defaults use `| default()` fallbacks,
      not client-specific values
- [ ] **No secrets in plaintext**: If the tool needs API keys, they are vault
      variables referenced as `vault_*` and injected via iron-proxy's `secrets`
      transform
- [ ] **`community.docker` modules** for the proxy deployment (never
      `docker compose`)
- [ ] **Port conflict check** done — no conflicts with existing services or
      sandbox profiles
- [ ] **Subnet conflict check** done — no overlaps with existing Docker networks
- [ ] **Allowlist is default-deny** — `proxy_iron_proxy_allowlist_warn: false`
- [ ] **Method policy enforced** — GET + HEAD default, scoped POSTs per-host
- [ ] **Filesystem isolation** — `--read-only`, `--tmpfs /tmp`, `--cap-drop ALL`,
      `--security-opt no-new-privileges`, no host volume mounts except CA cert
- [ ] **CA certificate distributed** — mounted into container system CA
      directory, `update-ca-certificates` runs on entry
- [ ] **`just` recipe tested** — tool runs through the sandbox successfully
- [ ] **Egress verified** — non-allowlisted hosts return 403
- [ ] **Tool catalog metadata**: Entry added to `tools.yml` with `source_repo`
      field (Phase 5a)
- [ ] **`source_repo` link valid**: Points to the primary source repo
- [ ] **Client catalog regenerated**: `just generate-tool-catalog` run
      (Phase 5b)
- [ ] **Repo-root catalog regenerated**: `just generate-tool-catalog-shared`
      run (Phase 5b)
- [ ] **Lint passes**: `devbox run -- just ansible-lint-internal`

## Context Declaration

### File Paths

- **This workflow**:
  `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-sandboxed-cli-tool.md`
- **Service workflow (sibling)**:
  `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`
- **ADR**:
  `~/p/gh/levonk/infrahub/shared/active/08-docs/adr/adr-202608051501-sandboxed-cli-egress.md`
- **Developer guide**:
  `~/p/gh/levonk/infrahub/.agents/knowledge/developer.md`
- **Infrastructure schemas**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/infrastructure/`
- **Tool catalog metadata**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/infrastructure/tools.yml`
- **Tool catalog generator**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/scripts/generate_tool_catalog.py`
- **Generated catalog (client)**:
  `~/p/gh/levonk/infrahub/levonk/TOOLS.md` — auto-generated, do not edit manually
- **Generated catalog (repo-root)**:
  `~/p/gh/levonk/infrahub/TOOLS.md` — auto-generated, do not edit manually
- **Sandbox proxy role**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/roles/sandbox-cli-proxy/`
- **Sandbox proxy playbook**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/deploy-sandbox-proxy.yml`
- **Client allowlist vars**:
  `~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/group_vars/sandbox_proxy_hosts.yml`
- **Existing iron-proxy role (AI proxy chain, for reference)**:
  `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/roles/proxy-iron-proxy/`

### Project Info

See `AGENTS.md` (environment, vault, deployment, architectural invariants) and
`developer.md` (devbox/rtk, key directories, boundaries, known gotchas).

### Key Differences from the Service Workflow

| Aspect | Service workflow | This workflow |
|--------|-----------------|---------------|
| Container lifecycle | Long-running, managed | Ephemeral, `--rm`, exit on completion |
| Management | Ansible `docker_container` (declarative) | `docker run` via `just` recipe (imperative) |
| Catalog | `services.yml` → `SERVICES.md` | `tools.yml` → `TOOLS.md` |
| Traefik routing | Yes (if public domain) | No (CLI tools have no web endpoint) |
| Healthchecks | Yes | No (ephemeral) |
| Volumes | Persistent data volumes | None (read-only + tmpfs) |
| Dashboard | Homepage / TraLa integration | No |
| Orchestrator | Yes (research/PRD/deploy/verify) | No (simpler, no PRD needed) |
| Egress control | Via deployed iron-proxy / Traefik | Via sandbox-cli-proxy (dedicated iron-proxy instance) |
| Filesystem | Writable volumes | `--read-only` + `--tmpfs /tmp` |
| Capabilities | Service-specific | `--cap-drop ALL` + `--security-opt no-new-privileges` |
