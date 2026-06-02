# Agent Guidelines for localnet

## IP and Port Configuration Rules

### CRITICAL: All IP Addresses and Ports Must Be Variables

**ABSOLUTELY FORBIDDEN**: Hardcoded IP addresses and port numbers in configuration files, especially in Ansible tasks and Docker Compose files.

**REQUIRED**: All IP addresses and port numbers must be defined as variables.

#### Examples of Violations

**❌ FORBIDDEN - Hardcoded ports in Ansible tasks:**
```yaml
ports:
  - "8888:8888/tcp"
  - "8388:8388/tcp"
  - "8388:8388/udp"
  - "6881:6881/udp"
```

**❌ FORBIDDEN - Hardcoded container ports:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:80/tcp"
  - "{{ proxy_https_transparent_port }}:443/tcp"
  - "{{ proxy_envoy_internal_host_port }}:3129/tcp"
  - "{{ proxy_envoy_admin_host_port }}:9901/tcp"
```

**✅ REQUIRED - All ports as variables:**
```yaml
ports:
  - "{{ proxy_http_transparent_port }}:{{ proxy_http_container_port }}/tcp"
  - "{{ proxy_https_transparent_port }}:{{ proxy_https_container_port }}/tcp"
  - "{{ proxy_envoy_internal_host_port }}:{{ proxy_envoy_internal_container_port }}/tcp"
  - "{{ proxy_envoy_admin_host_port }}:{{ proxy_envoy_admin_container_port }}/tcp"
```

#### Examples of IP Address Violations

**❌ FORBIDDEN - Hardcoded IP addresses:**
```yaml
ansible_host: 127.0.0.1
docker_network_gateway: "172.26.0.1"
bindaddress: 0.0.0.0
```

**✅ REQUIRED - All IPs as variables:**
```yaml
ansible_host: "{{ ansible_host_ip }}"
docker_network_gateway: "{{ docker_network_gateway }}"
bindaddress: "{{ service_bind_address }}"
```

#### Rationale

- **Portability**: Variables allow easy deployment across different environments
- **Flexibility**: Changes can be made in one place (group_vars, .env files) without touching configuration files
- **Security**: Sensitive network topology details can be externalized
- **Maintainability**: Centralized configuration management

#### Enforcement

All new configuration must:
1. Define all ports as variables in `group_vars/all.yml` or service-specific `.env` files
2. Define all IP addresses as variables, including:
   - Network gateways and subnets
   - Service bind addresses (use variables instead of `0.0.0.0` or `127.0.0.1`)
   - Container IP assignments
3. Never hardcode port numbers in `ports:` sections (both host and container ports must be variables)
4. Never hardcode IP addresses in any configuration file

#### Current Violations to Fix

The following files contain hardcoded ports or IPs and need to be refactored:

**Ansible Tasks:**
- `shared/active/02-config/ansible/roles/vpn/tasks/main.yml` (lines 40-45)
- `shared/active/02-config/ansible/roles/proxy/tasks/main.yml` (lines 138-141 - container ports)

**Docker Compose Files:**
- `shared/active/03-container/services/vpn/docker-compose.vpn.yml` (lines 20-25)
- `shared/active/03-container/services/dns/adguard/docker-compose.adguard.yml` (lines 14-16)
- Various other docker-compose files with hardcoded ports

When working on localnet, always check for hardcoded IPs and ports before committing changes.

## Developer UX Workflow

This repository follows **ADR-20260131001** (Standard Developer UX Flow) and **ADR-20260419001** (NX Monorepo Build Tool).

### Tooling Stack (Root Files)

| File | Purpose | Standard |
|------|---------|----------|
| `devbox.json` | Environment definition, packages, scripts | ADR-20260131001 |
| `justfile` | Command runner (normal + *-internal targets) | ADR-20260131001 |
| `nx.json` | Monorepo build orchestration & caching | ADR-20260419001 |
| `.envrc` | direnv hook for auto-activation | ADR-20260131001 |

All three files live at the repository root. Component-specific justfiles (e.g., `shared/active/03-container/justfile`) handle subsystem commands; the root justfile delegates to them.

### Standard Flow: `direnv → devbox → just (*-internal) → [build tool]`

**For AI agents and automated systems:**
```bash
# Primary pattern — devbox run + *-internal target
devbox run just build-internal       # build
devbox run just test-internal        # test
devbox run just lint-internal        # lint
devbox run just doctor-internal      # health check
```

**For human developers (one-off convenience):**
```bash
# Normal target auto-ensures devbox environment
just build      # → devbox run build → just build-internal
just test       # → devbox run test → just test-internal
just lint       # → devbox run lint → just lint-internal
```

**For developers already in devbox shell:**
```bash
just build-internal      # direct call, no wrapper overhead
just test-internal
```

### Cloud Server / Ansible Commands

| Command | Purpose | Phase |
|---------|---------|-------|
| `devbox run packer-validate` | Validate Packer base image config | 01 |
| `devbox run packer-build` | Build OCI base VM image | 01 |
| `devbox run ansible-lint` | Lint all roles & playbooks | 04 |
| `devbox run ansible-syntax` | Check playbook syntax | 04 |
| `devbox run ansible-test` | Run Molecule tests (Docker containers) | 04 |
| `just molecule-test <role>` | Test specific role via Molecule | 04 |
| `devbox run ansible-deploy-bootstrap` | Deploy bootstrap to OCI | 05 |
| `devbox run ansible-deploy-vpn` | Deploy VPN layer to OCI | 05 |
| `devbox run ansible-deploy-infra` | Deploy infrastructure to OCI | 05 |
| `devbox run ansible-deploy-vms` | Deploy VM layer to OCI | 05 |
| `devbox run ansible-validate-bootstrap` | Validate bootstrap deployment | 06 |
| `devbox run ansible-validate-vpn` | Validate VPN deployment | 06 |
| `devbox run ansible-validate-infra` | Validate infrastructure | 06 |
| `devbox run ansible-validate-vms` | Validate VM layer | 06 |

### Docker Test Environment (Molecule)

Ansible roles are tested inside Docker containers via Molecule:

```bash
# Build the test image
just ansible-test-env-build

# Run a specific role's Molecule scenario
just molecule-test host-os-bootstrap
just molecule-test nix-installation
just molecule-test docker-engine

# Cleanup test container
just ansible-test-env-stop
```

### NX Monorepo Targets

```bash
# View task graph
nx graph

# Lint all Ansible roles & playbooks
nx run infrahub-ansible:lint

# Deploy bootstrap via NX
nx run infrahub-ansible:deploy-bootstrap

# Build LocalNet Docker services
nx run infrahub-localnet:docker:build
```

### Devbox Script Generation Bug (Known Issue)

`devbox run <script>` may fail with "command not found" in devbox v0.14.x+ (upstream issues #2517, #2108, #2607).

**Workarounds:**
1. **Use `just` directly** (recommended): `just ansible-lint` instead of `devbox run ansible-lint`
2. **Enter devbox shell first**: `devbox shell` then `just ansible-lint-internal`
3. **Rollback devbox**: `export DEVBOX_USE_VERSION=0.13.7`

The `justfile` normal targets already handle this by calling `devbox run <script>` which triggers `just <script>-internal`.

### Bootstrap & Setup

```bash
# Full environment bootstrap (called by devbox init_hook)
just bootstrap-internal

# Health check
just doctor-internal
```

---

## Repository Structure

This repository uses a two-tier hierarchy at the root:

```text
infrahub/
  shared/active/          # Reusable infrastructure code (roles graduate to levonk Galaxy namespace)
    00-os/
    01-build/
    02-config/ansible/    # Shared roles, playbooks, templates
    03-container/         # Docker compose files, container configs
    04-deploy/
    05-gitops/
    06-provision/
    07-local/
    08-docs/

  <client>/active/        # Client-specific overrides (inventories, host_vars, secrets)
    02-config/ansible/
      inventories/
      host_vars/
      group_vars/
```

- **`shared/active/`** contains all reusable roles, playbooks, and container definitions. Roles here are the source of truth that may graduate to the `levonk` namespace on Ansible Galaxy.
- **Client directories** (e.g., `levonk/`, `client-acme/`) contain only client-specific data: inventories, host variables, group variables, and vaulted secrets. They never contain roles or playbooks.

## Ansible Architecture

### Separation of Concerns

| Layer | Location | Rule |
|-------|----------|------|
| **Roles** | `shared/active/02-config/ansible/roles/` | Reusable, pure, parameterized. No client data. |
| **Playbooks** | `shared/active/02-config/ansible/playbooks/` | Stack blueprints. Import roles, select hosts. |
| **Inventories** | `<client>/active/02-config/ansible/inventories/` | Hosts, groups, which stacks go where. |
| **Variables** | `<client>/active/02-config/ansible/group_vars/` + `host_vars/` | Client-specific IPs, ports, secrets, feature flags. |

**Critical rule**: Playbooks live in `shared/`. Inventories and vars live in client directories. A playbook references its inventory at runtime via `-i`.

### Role Naming Convention

All roles in `shared/` must use **functional-group prefixes** to keep the directory scannable:

```text
roles/
  common/                 # Unprefixed — cross-cutting infrastructure
  docker-host/

  vpn-netbird/            # One role per VPN provider
  vpn-tailscale/
  vpn-wireguard/
  vpn-gluetun/
  vpn-twingate/
  vpn-tor/

  dns-adguard/
  dns-coredns/
  dns-dnsdist/

  proxy-traefik/
  proxy-envoy/
  proxy-squid/
  proxy-privoxy/
  proxy-crowdsec/
  proxy-authelia/
```

**Why**: With 15+ roles, flat naming is unmaintainable. Prefixes cluster related roles and prevent collisions (e.g., `netbird` could mean the SaaS, client, or control plane).

**Do not** create separate roles for sub-components of a single provider. `vpn-netbird/` should include management, signal, relay, and gateway-agent tasks as internal includes, not as `netbird-mgmt-service/`, `netbird-signal-service/`, etc.

**Why not subdirectories?** Ansible's role loader resolves `roles/<name>/` directly under `roles_path`. `roles/dns/adguard/` is not discoverable as role `adguard` by default. Prefixing (`dns-adguard/`) is the only way to cluster related roles while keeping them valid Ansible roles.

### Playbook Structure

Playbooks are stack blueprints. Each targets a functional group defined in the inventory:

```yaml
# shared/active/02-config/ansible/playbooks/stacks/baseline.yml
- name: "Deploy Baseline"
  hosts: baseline_servers
  become: true
  roles:
    - common
    - docker-host
```

The site playbook imports stacks:

```yaml
# shared/active/02-config/ansible/playbooks/site.yml
- import_playbook: stacks/baseline.yml
- import_playbook: stacks/docker-host.yml
- import_playbook: stacks/dns.yml
- import_playbook: stacks/proxy.yml
- import_playbook: stacks/vpn.yml
```

**Do not** put `when: dns_stack_enabled` boolean flags in playbooks. Use inventory group membership instead:

```yaml
# client/levonk/active/02-config/ansible/inventories/localnet.yml
all:
  children:
    baseline_servers:
      hosts:
        cloud-primary:
    dns_servers:
      children:
        baseline_servers:
    proxy_servers:
      children:
        baseline_servers:
```

### Variable Scoping

1. **Role defaults** (`roles/<role>/defaults/main.yml`): Neutral, overridable defaults. Must not reference `localnet_*` paths.
2. **Client group_vars** (`<client>/group_vars/all.yml`): Client-specific overrides (IPs, ports, feature flags).
3. **Client host_vars** (`<client>/host_vars/<host>.yml`): Host-specific overrides.
4. **Vaulted secrets** (`<client>/group_vars/all.vault`): Encrypted secrets. Never in `shared/`.

**No `group_vars/all.yml` in `shared/`**. All variable data is client-scoped.

## Ansible Galaxy Collection Strategy

### Long-Term Goal

Reusable roles in `shared/` graduate to collections in the `levonk` namespace. Collections are developed and versioned within this repo, then published to Ansible Galaxy:

```text
infrahub/
  shared/active/02-config/ansible/
    roles/              # Stage 1 & 2: roles under active development
    collections/        # Stage 3+: collections ready for Galaxy
      ansible_collections/
        levonk/
          vpn/
            galaxy.yml
            roles/
            playbooks/
          proxy/
            galaxy.yml
            roles/
    playbooks/
    inventories/
  <client>/active/02-config/ansible/
    inventories/
    host_vars/
    group_vars/
```

### Collection Development Path

Collections are developed in-tree under `shared/active/02-config/ansible/collections/`, already wired in `ansible.cfg`:

```ini
# shared/active/02-config/ansible/ansible.cfg
collections_paths = collections
```

For a collection to be recognized by Ansible, it must follow the strict FQCN hierarchy:

```text
collections/
  ansible_collections/
    levonk/
      vpn/
        galaxy.yml
        roles/
        playbooks/
      proxy/
        galaxy.yml
        roles/
```

**The `ansible_collections/<namespace>/<collection>/` path is mandatory.** You cannot flatten this or use arbitrary directory names. Ansible resolves `levonk.vpn.netbird` by walking `ansible_collections/levonk/vpn/roles/netbird/`.

### When to Promote to Collection

**Do not** move a role into `collections/` until it is:
- Free of client-specific defaults (no `localnet_*` paths, no hardcoded IPs)
- Stable (no changes for 2-3 weeks)
- Tested against at least two clients

### Migration Path

1. **Stage 1**: Local prefixed role in `shared/active/02-config/ansible/roles/vpn-netbird/`
2. **Stage 2**: Genericize defaults, remove localnet-specific paths
3. **Stage 3**: Move to `shared/active/02-config/ansible/collections/ansible_collections/levonk/vpn/roles/netbird/`
4. **Stage 4**: Publish to Galaxy, consume in this repo via `requirements.yml`:

```yaml
# <client>/active/02-config/ansible/requirements.yml
collections:
  - name: levonk.vpn
    source: https://galaxy.ansible.com
```

### Client Namespaces

If a client needs a custom role that is not suitable for the public `levonk` namespace:
- Keep it in `shared/active/02-config/ansible/roles/` with a `client-<name>-` prefix (e.g., `client-acme-auth/`)
- Or create a private Galaxy collection under the client's own namespace

## Small Business Profiles

Common deployment profiles for client onboarding:

| Profile | Stacks | Services |
|---------|--------|----------|
| `minimal-cloud` | baseline, docker-host, dns, proxy | SSH hardening, DNS, reverse proxy |
| `secure-remote` | minimal-cloud + vpn | + WireGuard / Tailscale |
| `full-mesh` | secure-remote + netbird-control | + Netbird control plane |

Profiles are expressed as group membership in the client's inventory, not as playbook conditionals.
