---
# Product Requirements Document (PRD)

## Introduction / Overview
- **Feature name:** Nix Cache Chain — Regional Multi-Layer Caching with Parallel Racing
- **Summary:** Deploy a multi-layered Nix binary cache chain across the levonk infrastructure: local Harmonia on every machine, regional ncps+ncro pairs for NAR caching and parallel upstream racing, and Attic on OCI as the cloud binary cache. This replaces the outdated sequential "waterfall" strategy with a modern architecture that races all upstreams in parallel while still providing LAN bandwidth savings through local NAR caching.
- **Context:**
  - The existing `nix-package-store.md` strategy doc describes a waterfall: Harmonia → ncps → Attic → Garnix → nixos.org. Research shows this is outdated because Nix walks substituters sequentially, adding latency on each miss.
  - New tools (ncro) race all upstreams in parallel and learn which is fastest via EMA latency tracking.
  - ncps still provides value as a local NAR cache (bandwidth savings for LAN), but should be paired with ncro behind it for parallel racing.
  - Existing container definitions exist as Nix flakes under `shared/active/03-container/services/artifact/` (nix-attic, nix-harmonia, nix-ncps) but there are NO Ansible roles for deploying them.

## Goals
- Every machine in the infrastructure runs Harmonia locally (127.0.0.1) to serve its own /nix/store
- Two regional ncps+ncro pairs provide NAR caching and parallel upstream racing
- Attic runs on oci-cloud-server as the cloud binary cache
- All machines' nix.conf is configured with the correct substituter chain
- All services are deployed via Ansible roles using community.docker modules (no docker compose)
- All ports, domains, and storage paths use infrastructure variables (no hardcoding)

## User Stories
- As a developer on a Mac, when I build a Nix derivation, my machine first checks its local /nix/store via Harmonia (instant), then the regional ncps on Windows (LAN fast), which caches the NAR for next time and uses ncro to race all upstreams in parallel for misses.
- As a developer on the OCI cloud server, when I build a Nix derivation, my machine checks local Harmonia, then the regional ncps on OCI, which uses ncro to race all Harmonia instances + Attic + public caches.
- As the infrastructure owner, I can monitor all cache services via Prometheus metrics and health endpoints.

## Functional Requirements

### FR-1: Harmonia on Every Nix Machine
- Deploy Harmonia as a container on all 5 Nix-running machines:
  - lzkmbp2016 (macOS, OrbStack)
  - lzkmbp2018 (macOS, OrbStack)
  - dtop202311 (Windows, Docker Desktop)
  - oci-cloud-server (Linux, Docker)
  - isolation-vm (Linux, Docker, accessed via SSH proxy through OCI)
- kckinai is EXCLUDED (not running Nix, only Docker for AI models)
- Mac mini is not yet deployable (not in inventory)
- Harmonia reads /nix/store:ro from the host
- Harmonia binds to 127.0.0.1 only (local access, not exposed to network)
- Harmonia requires a signing key (stored in vault for non-Mac, generated locally for Macs)
- Port: use infrastructure variable `infra_port_nix_harmonia_container` (default 5000)

### FR-2: ncps on Regional Hubs (2 deployments)
- Deploy ncps on:
  - dtop202311 (Windows) — serves LAN region (Macs, Windows, kckinai)
  - oci-cloud-server (OCI) — serves cloud region (oci-cloud-server, isolation-vm)
- ncps stores NARs locally (bind mount to host storage)
- ncps upstream is the regional ncro instance
- ncps binds to 0.0.0.0 (accessible via Tailscale from region clients)
- Port: use infrastructure variable `infra_port_nix_ncps_container` (default 8080)

### FR-3: ncro on Regional Hubs (2 deployments)
- Deploy ncro on:
  - dtop202311 (Windows) — co-located with LAN ncps
  - oci-cloud-server (OCI) — co-located with cloud ncps
- ncro races all upstreams in parallel:
  - All Harmonia instances (all 5 Nix-running machines, via Tailscale IPs/FQDNs)
  - Attic on OCI
  - Cachix (if credentials available)
  - cache.nixos.org
- ncro binds to 127.0.0.1 (only ncps talks to it, not external clients)
- Port: use infrastructure variable `infra_port_nix_ncro_container` (default 8081)
- ncro config is TOML, deployed via Ansible template

### FR-4: Attic on OCI
- Deploy Attic on oci-cloud-server as a container
- Attic uses local storage (bind mount)
- Attic binds to 0.0.0.0 (accessible via Tailscale)
- Port: use infrastructure variable `infra_port_nix_attic_container` (default 8082)
- Attic requires `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` (stored in vault)
- Attic requires `attic.toml` configuration (deployed via Ansible template)

### FR-5: nix.conf Configuration on All Machines
- Configure /etc/nix/nix.conf (or equivalent) on all machines with substituters:
  ```
  substituters = [
    "http://127.0.0.1:<harmonia_port>?priority=10"
    "http://<regional_ncps_tailscale_ip>:<ncps_port>?priority=20"
  ]
  ```
- Regional ncps IP:
  - LAN machines → dtop202311 Tailscale IP
  - Cloud machines → oci-cloud-server Tailscale IP
- Include trusted-public-keys for all caches

### FR-6: Ansible Roles (Shared)
- Create 4 Ansible roles in `shared/active/02-config/ansible/roles/`:
  - `nix-harmonia/` — deploys Harmonia container
  - `nix-ncps/` — deploys ncps container
  - `nix-ncro/` — deploys ncro container
  - `nix-attic/` — deploys Attic container
- All roles use `community.docker.docker_container` (never docker compose, never systemd)
- All roles follow the standard role structure (defaults, handlers, meta, tasks, templates, vars)
- All ports/IPs/domains reference infrastructure variables (no hardcoding)

### FR-7: Infrastructure Variables
- Add to `shared/active/02-config/ansible/infrastructure/ports.yml`:
  - `infra_port_nix_harmonia_host` / `infra_port_nix_harmonia_container`
  - `infra_port_nix_ncps_host` / `infra_port_nix_ncps_container`
  - `infra_port_nix_ncro_host` / `infra_port_nix_ncro_container`
  - `infra_port_nix_attic_host` / `infra_port_nix_attic_container`
- Add to `levonk/active/02-config/ansible/infrastructure/storage.yml`:
  - Storage paths for ncps NAR cache, Attic data, ncro SQLite
- Add to `levonk/active/02-config/ansible/infrastructure/networks.yml`:
  - Tailscale IPs for all machines (for ncro upstream config)

### FR-8: Playbooks and Inventory
- Create playbook `shared/active/02-config/ansible/playbooks/stacks/nix-cache.yml`
- Add inventory groups:
  - `nix_harmonia_hosts` (lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm)
  - `nix_ncps_hosts` (dtop202311, oci-cloud-server)
  - `nix_ncro_hosts` (dtop202311, oci-cloud-server)
  - `nix_attic_hosts` (oci-cloud-server)
- Add `nix_cache_enabled` flags to host_vars for per-machine opt-in

### FR-9: Vault Secrets
- Add to `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`:
  - `vault_nix_harmonia_sign_key` — Harmonia signing key
  - `vault_nix_attic_token_secret` — Attic HS256 secret
  - `vault_nix_attic_db_password` — Attic database password (if needed)
  - `vault_cachix_auth_token` — Cachix auth token (if used)
- Agent provides docker run command for user to edit vault (per AGENTS.md policy)

## Non-Functional Requirements
- **Performance**: Harmonia responds in <1ms for local store hits. ncps serves cached NARs in <10ms over LAN. ncro races complete in <100ms for narinfo lookup.
- **Security**: Harmonia binds to 127.0.0.1 only. ncro binds to 127.0.0.1 only. ncps and Attic bind to 0.0.0.0 but are only accessible via Tailscale (encrypted transport). All containers run with `no-new-privileges:true`. Signing keys in vault, never in shared/.
- **Reliability**: If local Harmonia is down, ncps still works. If ncps is down, clients can fall back to direct upstream access. If ncro is down, ncps falls back to sequential upstream queries.
- **Observability**: All services expose Prometheus metrics and health endpoints. Healthchecks configured on all containers.

## Current State
- **Relevant files and their roles:**
  - `shared/active/03-container/services/artifact/nix-harmonia/` — existing Nix flake container definition (flake.nix, README.md, Makefile). No Ansible role.
  - `shared/active/03-container/services/artifact/nix-ncps/` — existing Nix flake container definition + config.toml. No Ansible role.
  - `shared/active/03-container/services/artifact/nix-attic/` — existing Nix flake container definition. No Ansible role.
  - `shared/active/03-container/services/artifact/README.md` — overview of artifact services
  - `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md` — the outdated waterfall strategy doc (lines 170-231 describe the old chain)
  - `shared/active/03-container/internal-docs/requirements/nix/localnet-nix.md` — container analysis recommending Alpine base for cache services
  - `shared/active/02-config/ansible/roles/agentmemory/` — example Ansible role using community.docker.docker_container (pattern to follow)
  - `shared/active/02-config/ansible/roles/cloudflare-ddns/` — another example role with validation, templates, container deployment
  - `shared/active/02-config/ansible/infrastructure/ports.yml` — port allocation schema
  - `levonk/active/02-config/ansible/infrastructure/ports.yml` — client port values
  - `levonk/active/02-config/ansible/inventories/oci.yml` — OCI inventory (oci-cloud-server, isolation-vm)
  - `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — Mac inventory (lzkmbp2016, lzkmbp2018)
  - `levonk/active/02-config/ansible/inventories/windows-docker.yml` — Windows inventory (dtop202311)
  - `levonk/active/02-config/ansible/inventories/localnet.yml` — localnet inventory (kckinai)
  - `internal-docs/research/service/nix-cache-chain/tool-comparison.md` — research findings

- **Repository conventions:**
  - All container deployment uses `community.docker.docker_container` — NEVER docker compose, NEVER systemd (AGENTS.md Invariant #4, #5)
  - All ports/IPs/domains must be infrastructure variables — NEVER hardcoded (AGENTS.md IP and Port Configuration Rules)
  - `shared/` is client-agnostic — no client-specific values (AGENTS.md Invariant #1)
  - Secrets in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` — NEVER in shared/ (AGENTS.md Secret Storage Strategy)
  - Bind mounts use userns-remap UID 100000 (AGENTS.md Invariant #7)
  - Role naming: functional-group prefixes (e.g., `nix-harmonia`, not just `harmonia`)
  - Build on control machine, push to registry, pull on target (AGENTS.md Invariant #2)

- **Design constraints:**
  - ncro has no Docker image — must build from source (Nix flake or cargo build) and push to local registry
  - ncps has Docker image on Docker Hub/GHCR — can use `source: pull`
  - Attic has Nix flake build — build on Mac, push to local registry
  - Harmonia has Nix flake build — build on Mac, push to local registry
  - On macOS, Harmonia runs in OrbStack with /nix/store bind-mounted
  - ncro is not in nixpkgs — must use flake or build from source
  - ncro config is TOML format
  - ncps config is TOML/YAML/JSON format

## Technical Considerations

### Architecture Diagram
```
REGION 1: Local LAN (lzkmbp2016, lzkmbp2018, dtop202311)
  Each machine nix.conf:
    priority 10: http://127.0.0.1:5000  (local Harmonia)
    priority 20: http://<dtop202311-ts>:8080  (LAN ncps)

  dtop202311 runs:
    Harmonia @ 127.0.0.1:5000
    ncps @ 0.0.0.0:8080 → upstream: ncro @ 127.0.0.1:8081
    ncro @ 127.0.0.1:8081 → races:
      - http://lzkmbp2016-ts:5000 (Harmonia)
      - http://lzkmbp2018-ts:5000 (Harmonia)
      - http://dtop202311-ts:5000 (Harmonia, local)
      - http://oci-cloud-ts:5000 (Harmonia)
      - http://isolation-vm-ts:5000 (Harmonia)
      - http://oci-cloud-ts:8082 (Attic)
      - https://cache.nixos.org
      - https://<cachix>.cachix.org (if configured)

REGION 2: Cloud/OCI (oci-cloud-server, isolation-vm)
  Each machine nix.conf:
    priority 10: http://127.0.0.1:5000  (local Harmonia)
    priority 20: http://<oci-cloud-ts>:8080  (cloud ncps)

  oci-cloud-server runs:
    Harmonia @ 127.0.0.1:5000
    ncps @ 0.0.0.0:8080 → upstream: ncro @ 127.0.0.1:8081
    ncro @ 127.0.0.1:8081 → races: (same upstream list as above)
    Attic @ 0.0.0.0:8082

  isolation-vm runs:
    Harmonia @ 127.0.0.1:5000 only (no ncps/ncro, uses OCI's ncps)

  Excluded:
    kckinai — not running Nix (Docker-only AI inference host)
```

### Image Build Strategy
- Harmonia: `nix build .#docker-prod` → `docker load` → `docker tag <registry>/nix-harmonia:latest` → `docker push`
- ncps: Pull `ghcr.io/kalbasit/ncps:latest` directly (Docker image available)
- ncro: Build from source (no Docker image available). Either Nix flake or cargo build → docker build → push to registry
- Attic: `nix build .#docker-prod` → `docker load` → `docker tag <registry>/nix-attic:latest` → `docker push`

### ncro Container Build
ncro has no official Docker image. Options:
1. Build a Docker image from the ncro repo using a multi-stage Dockerfile (Rust build → minimal runtime)
2. Build via Nix flake if ncro provides one
3. Create a Nix flake in `shared/active/03-container/services/artifact/nix-ncro/` following the pattern of nix-harmonia/nix-ncps

## Verification Approach
| Purpose | Command | Expected Result |
|---------|---------|-----------------|
| Ansible lint | `cd ~/p/gh/levonk/infrahub && devbox run -- rtk ansible-lint` | exit 0, no warnings |
| Ansible syntax | `devbox run -- rtk ansible-playbook --syntax-check` | exit 0 |
| Dry run | `devbox run -- rtk ansible-playbook -i <inv> playbooks/stacks/nix-cache.yml --check --diff` | exit 0, shows changes |
| Harmonia health | `curl http://127.0.0.1:5000/nix-cache-info` on each machine | Returns cache info |
| ncps health | `curl http://<ncps-host>:8080/healthz` | Returns healthy |
| ncro health | `curl http://<ncro-host>:8081/health` | Returns JSON with upstream status |
| Attic health | `curl http://<oci-cloud>:8082/api/v1/` | Returns API response |
| nix substitution | `nix path-info --substituters 'http://127.0.0.1:5000' <store-path>` | Resolves from local Harmonia |

## Success Criteria (Machine-Checkable)
- [ ] `devbox run -- rtk ansible-lint` passes with 0 warnings
- [ ] `devbox run -- rtk ansible-playbook --syntax-check` passes for nix-cache.yml
- [ ] Dry run (`--check --diff`) succeeds against all inventory groups
- [ ] Harmonia responds on 127.0.0.1:5000 on all 5 Nix-running machines after deployment
- [ ] ncps responds on its Tailscale IP:8080 on both regional hubs
- [ ] ncro /health returns JSON with all upstreams listed on both regional hubs
- [ ] Attic responds on oci-cloud-server:8082
- [ ] `nix path-info` resolves a path via local Harmonia on at least one machine
- [ ] No hardcoded IPs or ports in any role/playbook/template (grep verification)
- [ ] No secrets in shared/ directory (grep verification)

## Out of Scope
- nix-snapshotter (Kubernetes containerd integration) — separate feature, not needed for this deployment
- Garnix CI integration — not currently using Garnix
- Cachix deployment — optional, only if credentials are provided. If not available, ncro still races nixos.org + Attic + Harmonia instances
- Migration of existing Nix builds to push to Attic — separate workflow
- Web UI for Attic — Attic API only for now
- Prometheus/Grafana dashboards for cache metrics — separate monitoring feature
- selector4nix — not selected (ncro chosen for parallel racing)

## Risk Assessment
- **Priority:** P2
- **Effort:** L (4 new Ansible roles, 6 target machines, 2 architectures: Linux Docker + macOS OrbStack)
- **Risk:** MED
  - ncro has no Docker image — must build from source (mitigation: simple Rust build)
  - ncro is not in nixpkgs — must use flake or manual build (mitigation: create Nix flake)
  - macOS OrbStack /nix/store bind mount behavior may differ from Linux Docker (mitigation: test on one Mac first)
  - isolation-vm is behind SSH proxy — Ansible must handle this (existing pattern in inventory)
  - Windows Docker Desktop networking may need special config for Tailscale access (mitigation: existing roles work on dtop202311)

## Success Metrics
- All 5 Nix-running machines have working local Harmonia (verified by curl)
- Both regional ncps+ncro pairs are operational (verified by health endpoints)
- Attic on OCI is operational (verified by API endpoint)
- nix build operations on any machine use the cache chain (verified by nix path-info test)
- No regression in existing infrastructure deployments

## Open Questions
- Should Cachix be included as an ncro upstream? (Requires Cachix account and auth token in vault)
- ~~Should the outdated `nix-package-store.md` be updated or replaced with a new ADR documenting this architecture?~~ — DONE: ADR-20260708001 created, nix-package-store.md marked as superseded
- ~~Should we create a new ADR for this cache chain architecture?~~ — DONE: ADR-20260708001 created at `shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md`

## Dependencies
- Docker/OrbStack must be installed on all target machines (existing for most)
- Tailscale must be operational on all machines (existing)
- Local Docker registry must be running on OCI (existing: `deploy-local-registry.yml`)
- Nix must be installed on all target machines (existing for Macs via nix-darwin, may need verification for others)

## Timeline / Milestones
1. **M1: Build images** — Build Harmonia, ncro, Attic container images, push to local registry
2. **M2: Infrastructure variables** — Add ports, storage, network vars to shared + levonk infrastructure files
3. **M3: Vault secrets** — User adds Harmonia sign key + Attic secrets to vault
4. **M4: Ansible roles** — Create 4 roles (nix-harmonia, nix-ncps, nix-ncro, nix-attic)
5. **M5: Playbook + inventory** — Create nix-cache.yml playbook, add inventory groups
6. **M6: Deploy + test** — Deploy to all machines, verify health endpoints, test nix path-info
7. **M7: nix.conf configuration** — Configure substituters on all machines
8. **M8: End-to-end verification** — Verify cache chain works for real nix builds

## Maintenance Notes
- ncro upstream list must be updated when machines are added/removed from the infrastructure
- Harmonia signing key rotation requires updating all nix.conf trusted-public-keys
- Attic storage may need periodic cleanup (GC)
- ncps NAR cache may need periodic cleanup (LRU eviction is configurable)
- The `nix-package-store.md` doc should be updated to reflect this new architecture (or superseded by a new ADR)

## STOP Conditions
Stop and report back (do not improvise) if:
- The existing Nix flake definitions under `services/artifact/` don't build successfully
- ncro cannot be containerized (no Docker image, no Nix flake, cargo build fails)
- OrbStack on macOS cannot bind-mount /nix/store
- Docker Desktop on Windows cannot route to Tailscale IPs
- The isolation-vm SSH proxy pattern doesn't work for Ansible deployment
- A required secret cannot be added to the vault (user unavailable)
- Verification commands fail after reasonable fix attempts

---
*Generated from PRD template*
