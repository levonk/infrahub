---
workflow: "Add a New Service to Infrahub (Implementation Guide)"
slug: "infrahub-add-new-service"
description: "Phase-by-phase implementation guide for adding a new service: shared role, client infrastructure values, vault secrets, Traefik routing, build pipeline, playbook. Phases 1-8 only — orchestrator (do-new-srvc-infrahub.md) owns test/deploy/verify/commit."
use: "When implementing the actual deployment of a new service — called by do-new-srvc-infrahub.md or used directly for one-shot service additions"
date:
  created: "2026-06-30"
  updated: "2026-07-08"
  last-used: "2026-07-08"
see-also:
  - file: "do-new-srvc-infrahub.md"
    relationship: "orchestrator"
    description: "Orchestration workflow that handles research, planning, and PRD before delegating implementation to this guide. Owns test/deploy/verify/commit (Phases 4-7)."
  - skill: "container-image-build"
    relationship: "implementation"
    description: "Build container images for mixed-architecture fleets. Three branches: pre-built upstream, Dockerfile+buildx, Nix flake. Authoritative reference for the upstream-vs-locally-built decision and Phase 3 build pipeline."
  - skill: "container-service-deploy"
    relationship: "implementation"
    description: "Deploy multi-container services via compose (dev) or Ansible docker_container (prod). Authoritative reference for Phase 5 role creation."
  - skill: "infrahub-container-deploy"
    relationship: "implementation"
    description: "Infrahub-specific overlay for container deployment: userns-remap UID 100000, vault handoff, infra_ variable naming, functional-group role naming, local registry. Authoritative reference for Phase 5 role creation."
---

# Workflow: Add a New Service to Infrahub

This workflow guides an agent through adding a new service end-to-end: shared role, client infrastructure values, vault secrets, Traefik routing, build pipeline, and deployment. Follow every phase in order. Do not skip phases.

## Prerequisites

1. Read the root [`AGENTS.md`](../../AGENTS.md) — especially "Architectural Invariants" and "Per-Client Centralized Files"
2. Read the [Developer Guide](../knowledge/developer.md) — especially the critical-files tree and boundaries
3. Read [`shared/active/02-config/ansible/AGENTS.md`](../../shared/active/02-config/ansible/AGENTS.md) — container module rules, port conflict checking
4. Read [`levonk/AGENTS.md`](../../levonk/AGENTS.md) — submodule workflow, secret storage rules
5. Know the service name, upstream image/repo, what ports it needs, what domain it gets, and what secrets it requires

## Decision: Upstream Image vs Locally-Built Image

Before starting, determine which path applies. The `container-image-build` skill
(`~/p/gh/levonk/skills-src/src/current/skills/software-dev/container-image-build/SKILL.md`)
is the authoritative reference for this decision — it enforces "check pre-built
first" and "multi-arch mandatory" principles.

- **Upstream image** (e.g., `envoyproxy/envoy:v1.28-latest`, `ubuntu/squid:latest`, `ghcr.io/dakheera47/job-ops:latest`): The service uses a pre-built Docker Hub or GHCR image. No Dockerfile, no build pipeline entry. Skip Phase 3.
- **Locally-built image** (e.g., omniroute, headroom, agentmemory): The service has a custom Dockerfile in `shared/active/03-container/services/`. Requires build pipeline entry. Do Phase 3.

---

## Phase 1: Shared Infrastructure Schemas

Add the variable **schema** (neutral defaults) to the shared infrastructure files. These are defaults that any client can override.

### 1a. Ports — `shared/active/02-config/ansible/infrastructure/ports.yml`

Add port variables following the naming convention `infra_port_{CATEGORY}_{SERVICE}_{CONTEXT}_{HOST|CONTAINER}`:

```yaml
# {Service Name}
infra_port_{category}_{service}_host: "{port}"
infra_port_{category}_{service}_container: "{port}"
```

**Check for conflicts first**: scan this file AND `levonk/active/02-config/ansible/infrastructure/ports.yml` for the port you want. Also check `docker ps` on the target host. If conflicts, stop and surface to user.

### 1b. Networks — `shared/active/02-config/ansible/infrastructure/networks.yml`

If the service needs a new network or IP allocation:

```yaml
# {Service Name}
infra_network_{category}_{service}_network_name: "{network-name}"
infra_network_ip_{service}: "{ip-address}"
```

If the service joins an existing network (e.g., `traefik-network`, `proxy-chain-network`), no new network variable is needed — just reference the existing one in the role defaults.

### 1c. Domains — `shared/active/02-config/ansible/infrastructure/domains.yml`

If the service gets a public domain via Traefik:

```yaml
# {Service Name}
infra_domain_{category}_{service}: "{service}.levonk.com"
```

### 1d. Storage — `shared/active/02-config/ansible/infrastructure/storage.yml`

If the service needs a data volume or config directory:

```yaml
# {Service Name}
infra_storage_{service}_volume: "{volume-name}"
infra_storage_{service}_config_dir: "{{ infra_storage_services_dir }}/{service}"
```

---

## Phase 2: Client Infrastructure Values

Override the shared defaults with client-specific values in `levonk/active/02-config/ansible/infrastructure/`.

**Only add overrides here if the client value differs from the shared default.** If the shared default works, don't duplicate it.

### 2a. Ports — `levonk/active/02-config/ansible/infrastructure/ports.yml`

```yaml
# {Service Name} (client-specific override)
infra_port_{category}_{service}_host: "{port}"
infra_port_{category}_{service}_container: "{port}"
```

### 2b. Networks — `levonk/active/02-config/ansible/infrastructure/networks.yml`

```yaml
# {Service Name} IP allocation (client-specific)
infra_network_ip_{service}: "{ip-address}"
```

### 2c. Domains — `levonk/active/02-config/ansible/infrastructure/domains.yml`

```yaml
# {Service Name} (client-specific)
infra_domain_{category}_{service}: "{service}.levonk.com"
```

### 2d. Storage — `levonk/active/02-config/ansible/infrastructure/storage.yml`

Only if the client uses different paths than the shared defaults.

### 2e. DNS Record

If the service gets a public domain, add a CNAME record to the Cloudflare DNS configuration:

- File: `levonk/active/02-config/ansible/inventories/group_vars/all.yml` (or wherever `cloudflare_dns_records` is defined)
- Add: `{service}.levonk.com` → CNAME → `oci.tale-grouper.ts.net` (Tailscale FQDN)
- Deploy DNS: `devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/configure-cloudflare-dns.yml --vault-password-file ~/.ansible/vault_password`

---

## Phase 3: Build Pipeline (Locally-Built Images Only)

Skip this phase if using an upstream Docker Hub or GHCR image.

> **Authoritative reference**: The `container-image-build` skill
> (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/container-image-build/SKILL.md`)
> covers this comprehensively — three branches (pre-built, Dockerfile+buildx,
> Nix flake), multi-arch mandatory, check pre-built first. Use it instead of
> duplicating the guidance here.

### 3a. Create the Dockerfile

Create the Dockerfile under `shared/active/03-container/services/{category}/{service}/`:

```
shared/active/03-container/services/{category}/{service}/
├── docker/
│   └── Dockerfile.{service}     # or just Dockerfile at the root
├── docker-compose.{service}.yml  # reference compose file (not used for deployment)
└── README.md
```

**Multi-stage builds are mandatory** when the image has build dependencies (pip, npm, cargo, apt build-essential, etc.). See AGENTS.md Invariant #2.

### 3b. Register in build-and-push-images.sh

Add an entry to the `IMAGES` array in `scripts/build-and-push-images.sh`:

```bash
"localnet-{category}-{service}|docker/Dockerfile.{service}|{category}/{service}"
```

Format: `image_name|dockerfile_path_relative_to_context|context_dir_relative_to_SERVICES`

### 3c. Build and push

```bash
# Build and push the single image
devbox run -- just docker-build-push localnet-{category}-{service}

# Verify it's in the registry
docker manifest inspect 100.90.22.85:5000/localnet-{category}-{service}:latest
```

**If the OCI server is low on disk** (check with `ssh opc@100.90.22.85 'df -h /'`):
- The registry may need to be temporarily removed to free space
- Use `docker save | docker load` to transfer the image directly: `docker save 100.90.22.85:5000/localnet-{category}-{service}:latest | ssh opc@100.90.22.85 'docker load'`
- Redeploy the registry afterward: `devbox run -- ansible-playbook ... deploy-local-registry.yml`

---

## Phase 4: Vault Secrets

If the service needs secrets (API keys, passwords, tokens), add them to the vault.

### 4a. Identify required secrets

List every secret the service needs. For each:
- Variable name: `vault_{service}_{secret_name}` (e.g., `vault_agentmemory_hmac_secret`)
- Generation command (if applicable): `openssl rand -base64 32`, `openssl rand -hex 32`, etc.

### 4b. Add to vault file

**The agent MUST NOT edit the vault directly.** Instead, provide the user with a copyable `docker run` command:

```bash
docker run --rm -it \
  -v ~/.ansible/vault_password:/vault_password:ro \
  -v ~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

> **Why mount the directory, not the file?** `ansible-vault edit` writes to a temp
> file then atomically replaces the original via `os.remove()` + rename. Docker
> file bind mounts can't be removed from inside the container (`Errno 16: Resource
> busy`). Mounting the directory lets the atomic replace work normally.

Tell the user exactly what to add:

```yaml
# {Service Name}
vault_{service}_{secret_name}: "{generated_value}"
```

### 4c. Reference in role defaults

In the role's `defaults/main.yml`, reference the vault variable with a safe default:

```yaml
{service}_{secret_name}: "{{ vault_{service}_{secret_name} | default('') }}"
```

---

## Phase 5: Create the Ansible Role

Create the role under `shared/active/02-config/ansible/roles/{prefix}-{service}/`.

> **Authoritative references**:
> - `infrahub-container-deploy` skill
>   (`~/p/gh/levonk/infrahub/.agents/skills/devops/infrahub-container-deploy/SKILL.md`)
>   — infrahub-specific overlay: userns-remap UID 100000, vault handoff,
>   `infra_` variable naming, functional-group role naming, local registry.
> - `container-service-deploy` skill
>   (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/container-service-deploy/SKILL.md`)
>   — general deployment patterns (compose for dev, Ansible for prod).

### 5a. Role naming

Use functional-group prefixes (see AGENTS.md "Role Naming Convention"):
- `ai-` for AI services (e.g., `ai-litellm`, `ai-omniroute`)
- `dns-` for DNS services (e.g., `dns-adguard`, `dns-coredns`)
- `proxy-` for proxy services (e.g., `proxy-traefik`, `proxy-authelia`)
- `dashboard-` for dashboards (e.g., `dashboard-homepage`, `dashboard-trala`)
- `common-` for cross-cutting infrastructure

### 5b. Role structure

```
roles/{prefix}-{service}/
├── defaults/
│   └── main.yml          # Default variables (reference infra_* vars, never hardcode)
├── handlers/
│   └── main.yml          # Handlers (restart, reload)
├── meta/
│   └── main.yml          # Galaxy metadata
├── tasks/
│   └── main.yml          # Main task file (or split into includes)
├── templates/
│   └── *.yml.j2          # Config file templates
└── README.md             # Role documentation
```

### 5c. defaults/main.yml — critical rules

```yaml
---
# {Service Name} default variables

# Container configuration
{service}_container_name: "localnet-{service}"
{service}_image_name: "{{ local_registry | default('100.90.22.85:5000') }}/localnet-{service}"
{service}_image_tag: "latest"
# OR for upstream images:
# {service}_image_name: "{upstream-org}/{upstream-image}"
# {service}_image_tag: "{upstream-tag}"

# Ports (reference infrastructure variables)
{service}_host_port: "{{ infra_port_{category}_{service}_host | default('{default_port}') }}"
{service}_container_port: "{{ infra_port_{category}_{service}_container | default('{default_port}') }}"

# Network (reference infrastructure variables)
{service}_network_name: "{{ infra_network_{category}_{service}_network_name | default('{default_network}') }}"

# Domain (reference infrastructure variables)
{service}_domain: "{{ infra_domain_{category}_{service} | default('{service}.levonk.com') }}"

# Volume
{service}_volume_name: "{{ infra_storage_{service}_volume | default('localnet-{service}-data-volume') }}"

# Healthcheck — MUST use string with unit suffix, NOT bare integers
{service}_healthcheck_interval: "30s"
{service}_healthcheck_timeout: "5s"
{service}_healthcheck_retries: 3
{service}_healthcheck_start_period: "30s"

# Secrets (reference vault with safe default)
{service}_secret: "{{ vault_{service}_secret | default('') }}"
```

### 5d. tasks/main.yml — critical rules

```yaml
---
# {Service Name} Deployment

# 1. Validate required variables
- name: Validate required variables are defined
  ansible.builtin.assert:
    that:
      - {service}_container_name is defined
      - {service}_image_name is defined
      - {service}_host_port is defined
    fail_msg: "Missing required {service} variables."
    success_msg: "All required {service} variables are defined."
  tags: ["always", "validate"]

# 2. Volume
- name: Ensure {service} data volume exists
  community.docker.docker_volume:
    name: "{{ {service}_volume_name }}"
    state: present

# 3. Image pull — MUST use source: pull, NEVER source: build
- name: Pull {service} image
  community.docker.docker_image:
    name: "{{ {service}_image_name }}:{{ {service}_image_tag }}"
    source: pull
    state: present
  notify: restart {service}

# 4. Container — MUST use community.docker.docker_container, NEVER docker compose
- name: Deploy {service} container
  community.docker.docker_container:
    name: "{{ {service}_container_name }}"
    image: "{{ {service}_image_name }}:{{ {service}_image_tag }}"
    state: started
    restart_policy: unless-stopped
    networks:
      - name: "{{ {service}_network_name }}"
    ports:
      - "{{ {service}_host_port }}:{{ {service}_container_port }}/tcp"
    volumes:
      - "{{ {service}_volume_name }}:/data:rw"
    env:
      TZ: "{{ localnet_tz | default('UTC') }}"
    log_driver: json-file
    log_options:
      max-size: "10m"
      max-file: 5
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:{{ {service}_container_port }}/health || exit 1"]
      interval: "{{ {service}_healthcheck_interval }}"
      timeout: "{{ {service}_healthcheck_timeout }}"
      retries: "{{ {service}_healthcheck_retries }}"
      start_period: "{{ {service}_healthcheck_start_period }}"
  notify: restart {service}

# 5. Wait for health
- name: Wait for {service} to be healthy
  ansible.builtin.wait_for:
    host: "127.0.0.1"
    port: "{{ {service}_host_port }}"
    delay: 10
    timeout: 120
  when: {service}_deploy.changed | default(false)

# 6. Status report
- name: Get {service} container status
  community.docker.docker_container_info:
    name: "{{ {service}_container_name }}"
  register: {service}_container_info
  ignore_errors: true

- name: Report {service} status
  ansible.builtin.debug:
    msg: |
      {service} deployed:
        - URL: https://{{ {service}_domain }}
        - Container: {{ {service}_container_name }}
        - Status: {{ {service}_container_info.container.State.Status | default('unknown') }}
  tags: ["always", "info"]
```

### 5e. handlers/main.yml — critical rules

```yaml
---
# {service} handlers

- name: restart {service}
  community.docker.docker_container:
    name: "{{ {service}_container_name }}"
    state: started
    restart: true
```

**NEVER use `state: restarted`** — not valid in current `community.docker` version. Use `state: started` with `restart: true`.

### 5f. meta/main.yml

```yaml
---
galaxy_info:
  role_name: {service}
  author: localnet
  description: Deploy {Service Name}
  license: MIT
  min_ansible_version: "2.9"
  platforms:
    - name: Ubuntu
      versions:
        - jammy
```

---

## Phase 6: Traefik Routing (If Public Domain)

If the service gets a public domain, create a Traefik dynamic config template.

### 6a. Create the dynamic config template

File: `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/{service}-levonk-com.yml.j2`

```yaml
# Traefik Dynamic Configuration - {Service Name} Routing
# Generated by Ansible - DO NOT EDIT MANUALLY
# Domain: {{ {service}_domain }}
# Security: Authelia SSO (if auth required) or no middleware (if public)

http:
  routers:
    # HTTP router (redirects to HTTPS)
    {service}-http:
      rule: "Host(`{{ {service}_domain }}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: {service}

    # HTTPS router
    {service}-https:
      rule: "Host(`{{ {service}_domain }}`)"
      entryPoints:
        - websecure
      middlewares:
        - authelia  # Remove if public service (no auth needed)
      service: {service}
      tls:
        certResolver: letsencrypt

  services:
    {service}:
      loadBalancer:
        servers:
          - url: "http://{{ {service}_container_name }}:{{ {service}_container_port }}"
        passHostHeader: true
```

### 6b. Register in Traefik role tasks

Add a task to `shared/active/02-config/ansible/roles/proxy-traefik/tasks/main.yml`:

```yaml
- name: Deploy {service} dynamic configuration template
  ansible.builtin.template:
    src: dynamic/{service}-levonk-com.yml.j2
    dest: "{{ proxy_traefik_data_dir }}/config/dynamic/{service}-levonk-com.yml"
    owner: root
    group: root
    mode: '0644'
  notify: reload traefik
```

### 6c. Verify the service network

The service container MUST be on the `traefik-network` Docker network for Traefik to route to it. Check the role's `defaults/main.yml` — if the service uses a different primary network, add `traefik-network` as a second network in the `docker_container` task:

```yaml
    networks:
      - name: "{{ {service}_network_name }}"
      - name: "{{ infra_network_proxy_traefik_network_name | default('traefik-network') }}"
```

---

## Phase 7: Dashboard Integration (Optional)

### 7a. Homepage (`start.levonk.com`)

Add the service to the Homepage dashboard config:

- File: `shared/active/02-config/ansible/roles/dashboard-homepage/templates/homepage-services.yaml.j2`
- Add a service entry with href, icon, description

### 7b. TraLa (`start2.levonk.com`)

If the service has a Traefik router, TraLa will auto-discover it. To customize the display:

- File: `shared/active/02-config/ansible/roles/dashboard-trala/templates/trala-configuration.yml.j2`
- Add a service override:

```yaml
    - service: "{service}-https"
      display_name: "{Service Display Name}"
      icon: {service}.svg  # Must exist in selfh.st icon database
      group: "{Group Name}"
```

**Note**: TraLa exclude patterns use router names WITHOUT the `@file` suffix. Wildcards: `*` matches any chars, `?` matches one char.

---

## Phase 8: Create or Update Playbook

### 8a. Add to an existing stack playbook

If the service belongs to an existing stack (e.g., AI pipeline, DNS stack, proxy stack), add the role to that playbook:

```yaml
- name: "Deploy {Service Name}"
  hosts: cloud_servers
  become: true
  roles:
    - role: {prefix}-{service}
      tags: ["deploy", "{service}"]
```

### 8b. Create a new playbook (if new stack)

If the service is the first of a new stack:

```yaml
# shared/active/02-config/ansible/playbooks/deploy-{stack}-pipeline.yml
---
- name: "Deploy {Stack Name} Pipeline"
  hosts: cloud_servers
  become: true
  vars_files:
    - "{{ inventory_dir }}/group_vars/all.yml"
  roles:
    - role: common
    - role: {prefix}-{service}
      tags: ["deploy", "{service}"]
```

---

## Hand Back to Orchestrator

After Phase 8 (playbook created) and the checklist below passes, hand back to
the orchestrator (`do-new-srvc-infrahub.md`). The orchestrator owns:

- **Test** (Phase 4): syntax check, check mode, full `code-quality-validation`
- **Deploy** (Phase 5): `ansible-playbook` against the target inventory
- **Verify** (Phase 6): container health, Traefik routing, domain, cert, TraLa discovery
- **Deliver** (Phase 7): commit in both repos, AGENTS.md learnings

Do not deploy, verify, or commit from this workflow — that's the orchestrator's job.

---

## Checklist (Run Through Before Handing Back)

- [ ] **No hardcoded values**: All IPs, ports, domains, storage paths reference `infra_*` variables
- [ ] **No client data in shared/**: Role defaults use `| default()` fallbacks, not client-specific values
- [ ] **No secrets in plaintext**: All secrets are vault variables referenced as `vault_*`
- [ ] **`source: pull`** in docker_image task (never `source: build`)
- [ ] **`community.docker` modules** for all container operations (never `docker compose`)
- [ ] **Healthcheck durations** are strings with unit suffixes (`"30s"`, not `30`)
- [ ] **Handler uses** `state: started` + `restart: true` (not `state: restarted`)
- [ ] **Port conflict check** done — no conflicts with existing services
- [ ] **Traefik dynamic config** created and registered in Traefik role tasks (if public domain)
- [ ] **Service on traefik-network** if Traefik routes to it
- [ ] **DNS record** added and deployed (if public domain)
- [ ] **Build pipeline entry** added to `build-and-push-images.sh` (if locally-built image)
- [ ] **Image built and pushed** to registry (if locally-built)
- [ ] **Lint passes**: `devbox run -- just ansible-lint-internal`

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`
- **Orchestrator**: `~/p/gh/levonk/infrahub/.agents/workflows/do-new-srvc-infrahub.md`
- **Git state workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-git.md`
- **Developer guide**: `~/p/gh/levonk/infrahub/.agents/knowledge/developer.md` — critical-files tree, known gotchas, boundaries, definition of done
- **Infrastructure schemas**: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/infrastructure/` (ports.yml, networks.yml, domains.yml, storage.yml)
- **Client infra overrides**: `~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/infrastructure/`
- **Ansible roles**: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/roles/`
- **Playbooks**: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/`
- **Build script**: `~/p/gh/levonk/infrahub/scripts/build-and-push-images.sh`
- **Vault file**: `~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`

### Project Info

See `AGENTS.md` (environment, vault, deployment) and `developer.md` (devbox/rtk, key directories, boundaries, known gotchas).
