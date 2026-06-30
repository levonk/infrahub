# Workflow: Add a New Service to Infrahub

This workflow guides an agent through adding a new service end-to-end: shared role, client infrastructure values, vault secrets, Traefik routing, build pipeline, and deployment. Follow every phase in order. Do not skip phases.

## Prerequisites

1. Read the root [`AGENTS.md`](../../AGENTS.md) — especially "Architectural Invariants" and "Per-Client Centralized Files"
2. Read the [Developer Guide](../knowledge/developer.md) — especially the critical-files tree and boundaries
3. Read [`shared/active/02-config/ansible/AGENTS.md`](../../shared/active/02-config/ansible/AGENTS.md) — container module rules, port conflict checking
4. Read [`levonk/AGENTS.md`](../../levonk/AGENTS.md) — submodule workflow, secret storage rules
5. Know the service name, upstream image/repo, what ports it needs, what domain it gets, and what secrets it requires

## Decision: Upstream Image vs Locally-Built Image

Before starting, determine which path applies:

- **Upstream image** (e.g., `envoyproxy/envoy:v1.28-latest`, `ubuntu/squid:latest`): The service uses a pre-built Docker Hub image. No Dockerfile, no build pipeline entry. Skip Phase 3.
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

Skip this phase if using an upstream Docker Hub image.

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
  -v ~/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml:/vault.yml \
  --entrypoint ansible-vault \
  ghcr.io/ansible/community-ansible:v2.18.0 \
  edit /vault.yml --vault-password-file /vault_password
```

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

- File: `shared/active/02-config/ansible/roles/dashboard-homepage/templates/services.yml.j2` (or equivalent)
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

## Phase 9: Deploy and Verify

### 9a. Lint

```bash
devbox run -- just ansible-lint-internal
```

### 9b. Deploy

```bash
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/{playbook}.yml \
  --vault-password-file ~/.ansible/vault_password \
  --tags "{service}"
```

### 9c. Verify

```bash
# Container is running and healthy
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'docker ps --format "table {{.Names}}\t{{.Status}}" | grep {service}'

# Logs look correct
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'docker logs localnet-{service} --tail=20'

# Domain resolves and responds
curl -sI https://{service}.levonk.com

# Traefik has the router
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'curl -s -u trala:$(grep vault_traefik_api_auth_password levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml | cut -d\" -f2) http://127.0.0.1:8882/api/http/routers 2>&1 | python3 -c "import json,sys; [print(r[\"name\"]) for r in json.load(sys.stdin) if \"{service}\" in r[\"name\"]]"'

# Let's Encrypt cert is production (not staging)
echo | openssl s_client -connect {service}.levonk.com:443 -servername {service}.levonk.com 2>/dev/null | openssl x509 -noout -issuer
# Should show: issuer=C=US, O=Let's Encrypt, CN=YR2 (or R10/R11)
# NOT: issuer=C=US, O=Let's Encrypt, CN=(STAGING) ...
```

### 9d. Verify TraLa discovery (if public domain)

```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'curl -s http://127.0.0.1:8085/api/services | python3 -c "import json,sys; [print(s[\"Name\"],\"|\",s.get(\"group\",\"\")) for s in json.load(sys.stdin)]"'
```

The new service should appear with its display name and group.

---

## Phase 10: Commit

### 10a. Commit in the levonk submodule

```bash
cd levonk
git add .
git commit -m "feat: add {service} infrastructure values and vault secrets"
git push origin master
cd ..
```

### 10b. Commit in the infrahub parent repo

```bash
git add shared/ scripts/ justfile levonk
git commit -m "$(cat <<'EOF'
feat: add {service} service

- New role: shared/.../roles/{prefix}-{service}/
- Infrastructure schemas: ports, networks, domains, storage
- Traefik dynamic config: {service}-levonk-com.yml.j2
- Build pipeline: registered in build-and-push-images.sh (if locally-built)
- Dashboard: TraLa override and Homepage entry

Generated with [Devin](https://devin.ai)

Co-Authored-By: Devin <158243242+devin-ai-integration[bot]@users.noreply.github.com>
EOF
)"
```

---

## Checklist (Run Through Before Declaring Done)

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
- [ ] **Deployment succeeds** without fatal errors
- [ ] **Container healthy**: `docker ps` shows healthy status
- [ ] **Domain responds**: `curl -sI https://{service}.levonk.com` returns 200/302
- [ ] **Cert is production**: issuer is Let's Encrypt production (not STAGING)
- [ ] **TraLa shows service** with correct icon and group (if public domain)
- [ ] **Committed** in both levonk submodule and infrahub parent repo
- [ ] **Developer guide updated** if new patterns or gotchas discovered

---

## Common Pitfalls (From Developer Guide)

- **Disk space on OCI server (30G)**: Check `df -h /` before deploying. If full, `docker system prune -af` or temporarily remove the registry volume.
- **`localnet_network_subnet` undefined**: Pre-existing error in `common` role. Non-blocking — don't try to fix it.
- **Traefik Docker provider disabled**: All routing is via file-provider dynamic configs. Do NOT add traefik.* labels to containers.
- **ACME staging vs production**: Check `caServer` in Traefik static config. Delete staging certs from `acme.json` if cached.
- **Build caching**: `build-and-push-images.sh` skips unchanged images via context hash. Use `--force` to override.
- **Multi-platform `docker save`**: Build with `--platform linux/arm64` before `docker save | docker load` to avoid wasting disk.
- **TraLa exclude patterns**: Use router names WITHOUT `@file` suffix (e.g., `{service}-https`, not `{service}-https@file`).
- **envoy/privoxy/squid pattern**: Some services use upstream Docker Hub images directly — no custom Dockerfile needed.
