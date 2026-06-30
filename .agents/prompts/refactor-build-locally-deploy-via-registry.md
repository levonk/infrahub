# Prompt: Refactor All Roles to Build Locally + Deploy via Registry

## Context

**AGENTS.md Architectural Invariant #2** (just strengthened) requires: **build on the control machine (Mac), push to the local Docker registry, pull on the target. NEVER build on the target host.**

Currently **17 task files across 9 roles violate this rule** by using `community.docker.docker_image` with `source: build` while running against a target host. This builds ON the target, exhausting its disk (OCI server has 30G, was 100% full) with build layers and cache.

The local Docker registry already has a deployment playbook (`shared/active/02-config/ansible/playbooks/deploy-local-registry.yml`) that deploys a registry at `http://<cloud-server-tailscale-ip>:5000` (port `infra_port_registry_host` = 5000). It is NOT currently running — it needs to be deployed first.

## Goal

1. Deploy the local Docker registry on the OCI server
2. Refactor all 9 roles (17 task files) to stop building on the target and instead pull pre-built images from the registry
3. Create a justfile target (or local script) to build + push all locally-built images from the Mac
4. Build and push the headroom image, then deploy headroom to verify the pattern works end-to-end

## Affected Roles (17 files, 9 roles)

```
shared/active/02-config/ansible/roles/
├── agentmemory/tasks/main.yml
├── dns/tasks/adguard.yml
├── dns/tasks/blocklist-compiler.yml
├── dns/tasks/coredns.yml
├── dns/tasks/dnscrypt-plaintext.yml
├── dns/tasks/dnsdist.yml
├── dns/tasks/tor-proxy.yml
├── forward-proxy/tasks/9router.yml
├── forward-proxy/tasks/envoy.yml
├── forward-proxy/tasks/privoxy.yml
├── forward-proxy/tasks/squid.yml
├── isolation-vm-containers/tasks/base-kalinix.yml
├── isolation-vm-containers/tasks/hermes-agent.yml
├── isolation-vm-containers/tasks/nix-sidecar.yml
├── omniroute/tasks/main.yml
├── proxy-headroom/tasks/main.yml
└── proxy-tor/tasks/main.yml
```

**Reference (correct pattern):** `shared/active/02-config/ansible/roles/vpn-nordvpn/tasks/main.yml` uses `source: pull` — this is the pattern to follow.

## Steps

### Step 1: Deploy the local Docker registry

```bash
cd /Users/micro/p/gh/levonk/infrahub
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-local-registry.yml \
  --vault-password-file ~/.ansible/vault_password
```

Verify: `curl http://100.90.22.85:5000/v2/` should return `{}` (empty JSON).

Configure the Mac's Docker to trust the registry as insecure (HTTP):
- Docker Desktop → Settings → Docker Engine → add `"insecure-registries": ["100.90.22.85:5000"]`
- Or edit `~/.docker/daemon.json` and restart Docker
- Verify: `docker push 100.90.22.85:5000/test` should work

### Step 2: Create a build+push justfile target

Create a justfile recipe (or script) that builds and pushes all locally-built images from the Mac. For each role that currently builds on target:

1. Find the Dockerfile and build context (in `shared/active/03-container/services/...`)
2. **Ensure the Dockerfile uses multi-stage builds** if it has build dependencies (pip, npm, cargo, apt build-essential, etc.) that aren't needed at runtime. The builder stage installs compilers/tools; the runtime stage copies only the compiled artifacts. This keeps the final image small — the target pulls it from the registry, so smaller = less target disk and faster pull. Images that only add runtime packages to an existing base (e.g. `RUN apk add curl`) are the only exception. Currently 18 Dockerfiles already use multi-stage; ~70 are single-stage (many are sidecar/base images where the toolchain IS the runtime, which is fine). Any Dockerfile with build dependencies that is NOT multi-stage must be refactored to multi-stage as part of this work.
3. Build locally: `docker build -t 100.90.22.85:5000/<image-name>:<tag> -f <dockerfile> <context>`
4. Push: `docker push 100.90.22.85:5000/<image-name>:<tag>`

The image names should match what the roles expect (check each role's `defaults/main.yml` for the `*_image` variable). Tag them as `100.90.22.85:5000/<image-name>:latest`.

Consider a single `just build-and-push-all` target that loops over all locally-built images, plus per-service targets for incremental builds.

### Step 3: Refactor each role

For each of the 17 task files:

1. **Remove** the build context copy task (`ansible.builtin.copy` of Dockerfile/assets to target)
2. **Remove** the build context directory creation task on the target
3. **Change** `community.docker.docker_image` from `source: build` to `source: pull`
4. **Remove** the `build:` block (path, dockerfile, pull)
5. **Update** the image name in the role's `defaults/main.yml` to include the registry prefix: `100.90.22.85:5000/<image-name>:<tag>`
6. **Keep** the `docker_container` task as-is (it references the image name variable)

Example refactor (proxy-headroom):

**Before** (`tasks/main.yml`):
```yaml
- name: Ensure headroom build context directory exists on target
  ansible.builtin.file:
    path: "{{ localnet_services_dir }}/ai-codeassist/headroom"
    state: directory
  become: true

- name: Copy headroom build context to target
  ansible.builtin.copy:
    src: "{{ proxy_headroom_build_context }}/"
    dest: "{{ localnet_services_dir }}/ai-codeassist/headroom/"
  become: true

- name: Build headroom image
  community.docker.docker_image:
    name: "{{ proxy_headroom_image }}"
    build:
      path: "{{ localnet_services_dir }}/ai-codeassist/headroom"
      dockerfile: "Dockerfile.headroom"
      pull: false
    source: build
    state: present
  become: true
```

**After** (`tasks/main.yml`):
```yaml
- name: Pull headroom image from local registry
  community.docker.docker_image:
    name: "{{ proxy_headroom_image }}"
    source: pull
    state: present
  become: true
```

**Before** (`defaults/main.yml`):
```yaml
proxy_headroom_image: "headroom:latest"
```

**After** (`defaults/main.yml`):
```yaml
proxy_headroom_image: "100.90.22.85:5000/headroom:latest"
```

### Step 4: Build and push headroom (verify the pattern)

```bash
# Build headroom on the Mac
cd /Users/micro/p/gh/levonk/infrahub
docker build -t 100.90.22.85:5000/headroom:latest \
  -f shared/active/03-container/services/ai-codeassist/headroom/Dockerfile.headroom \
  shared/active/03-container/services/ai-codeassist/headroom/

# Push to the local registry
docker push 100.90.22.85:5000/headroom:latest

# Deploy headroom (now pulls from registry, no build on target)
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

Verify headroom is healthy:
```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'docker inspect --format="{{json .State.Health.Status}}" headroom'
```

### Step 5: Build and push all other locally-built images

For each of the other 16 task files, find the Dockerfile + build context, build on the Mac, push to the registry. Use the justfile target from Step 2.

### Step 6: Verify all refactored roles deploy cleanly

Run the main infrastructure playbook to verify all roles pull from the registry instead of building on target:

```bash
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/cloud-server-infra.yml \
  --vault-password-file ~/.ansible/vault_password
```

Check that no container is in a build state and all are healthy:
```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 \
  'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

### Step 7: Commit and push

Commit the AGENTS.md update (already done), the role refactors, the justfile target, and any new build scripts. Follow the infrahub git workflow (vertical commits by functionality).

## Key Files

- **AGENTS.md** (already updated): `/Users/micro/p/gh/levonk/infrahub/AGENTS.md` — Invariant #2 now explicitly describes the registry pattern
- **Registry playbook**: `shared/active/02-config/ansible/playbooks/deploy-local-registry.yml`
- **Registry port**: `infra_port_registry_host` = 5000 (in `shared/active/02-config/ansible/infrastructure/ports.yml`)
- **OCI server Tailscale IP**: 100.90.22.85
- **SSH access**: `ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85`
- **Vault password**: `~/.ansible/vault_password`
- **Correct pattern reference**: `shared/active/02-config/ansible/roles/vpn-nordvpn/tasks/main.yml` (uses `source: pull`)

## Critical Rules (from AGENTS.md)

- **NEVER use `docker compose`** — all container management via `community.docker` modules
- **NEVER build on the target** — build on Mac, push to registry, pull on target
- **All ports/IPs/domains must be variables** from infrastructure files
- **Secrets only in vault**, never in `shared/`
- **Traefik uses file provider only** (Docker provider disabled in v3.0)
- **Root cause first** — no workarounds, no band-aids
