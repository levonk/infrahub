# Nix Cache Chain + Garnix-CI Deployment on dtop202311

**Date**: 2026-08-07
**Session**: Deploying Nix cache chain (Harmonia + ncps + ncro) and garnix-ci on Windows Docker Desktop host (dtop202311) in the nl.levonk.com namespace
**Status**: Infrastructure complete, image building + deployment pending

## Current State

### Completed
- **Four Ansible roles created**: nix-harmonia, nix-ncps, nix-ncro, garnix-ci
- **ncps uses upstream image**: `ghcr.io/kalbasit/ncps:v0.9.4` (no build needed, CLI flags not TOML config)
- **ncro flake.nix created**: `shared/active/03-container/services/artifact/nix-ncro/flake.nix` builds Docker image from `github.com/manic-systems/ncro`
- **Harmonia flake.nix already existed**: `shared/active/03-container/services/artifact/nix-harmonia/flake.nix`
- **Infrastructure variables**: ports, domains, storage volumes added to shared + levonk infrastructure files
- **Traefik routing**: dynamic configs for `cache.nl.levonk.com` (ncps) and `ci.nl.levonk.com` (garnix-ci)
- **DNS CNAMEs**: `cache.nl.levonk.com` and `ci.nl.levonk.com` → `dtop202311.tale-grouper.ts.net`
- **Deployment playbook**: `deploy-nix-cache-and-garnix.yml`
- **Justfile targets**: `ansible-deploy-nix-cache-garnix`, `ansible-deploy-nix-cache`, `ansible-deploy-garnix-ci`
- **Documentation updated**: ADR-20260708001 ncro URL corrected to `github.com/manic-systems/ncro`
- **Syntax checks pass**: All roles and playbook validated
- **Committed**: `0079aae30b8bb59aab602e149f6ba4be5fb5cc33`

### Blocking Issues
1. **Harmonia + ncro Docker images not yet built**: Need to be built on dtop202311 (x86_64-linux) using Nix. The existing nix-sidecar container on dtop202311 provides the Nix environment.
2. **garnix-ci containerization is complex**: The open-sourced garnix-io/garnix-ci runs as NixOS VMs (via nixos-compose), not a simple Docker container. The Ansible role exists as scaffolding but the image build strategy needs investigation. The hosted garnix service shut down July 2026.
3. **WSL2 KVM support**: garnix-ci needs `/dev/kvm` for nested virtualization. Playbooks `enable-wsl2-kvm.yml` and `test-nested-virtualization.yml` were created to handle this, but haven't been tested on dtop202311 yet.

## Git State

**Commit at handoff**: `0079aae30b8bb59aab602e149f6ba4be5fb5cc33`

This is the exact repo state at handoff time. The receiving session can
reconstruct what was done by inspecting this commit and its history:
- `git show 0079aae` — what the handoff commit changed
- `git log 0079aae..HEAD` — work done since the handoff (during restoration)
- `git diff 0079aae~1 0079aae` — the last change before handoff

Note: There are also uncommitted changes in the working tree from other work
(sandbox-cli-proxy, devbox.json updates, bootstrap scripts, etc.) that are NOT
part of this handoff. Check `git status` to see them.

## Required Reading

Before any other action, read `/Users/micro/p/gh/levonk/infrahub/AGENTS.md` — it is the root of
this project's progressively-disclosed informational files (JIT index, binding
contracts, conventions). Follow its Usage Protocol and re-read the chain for
any path you touch.

Also read the Ansible-specific AGENTS.md:
`/Users/micro/p/gh/levonk/infrahub/shared/active/02-config/ansible/AGENTS.md`

And the artifact services AGENTS.md:
`/Users/micro/p/gh/levonk/infrahub/shared/active/03-container/services/artifact/AGENTS.md`

## Project Overview

### Objective
Deploy a regional Nix cache chain and CI builder on the Windows Docker Desktop host `dtop202311` in the `nl.levonk.com` namespace. The cache chain implements ADR-20260708001: a multi-layer architecture with parallel upstream racing.

### Architecture

```
Nix client
    │
    ▼
ncps (cache.nl.levonk.com)     ← front door, caches NARs locally
    │ (on cache miss)
    ▼
ncro (127.0.0.1:4525)          ← parallel racing proxy, stateless
    │ (races all upstreams)
    ├─► Harmonia (127.0.0.1:4523)  ← serves local /nix/store (priority 10)
    ├─► cache.nixos.org            ← (priority 20)
    ├─► cache.garnix.io            ← (priority 30)
    └─► nix-community.cachix.org   ← (priority 30)

garnix-ci (ci.nl.levonk.com)   ← CI builder, separate service
    │ uses /dev/kvm + shared nix store
```

### Current Status
All Ansible infrastructure is complete and syntax-checked. The next phase is building the Docker images that don't have upstream equivalents (Harmonia, ncro), then deploying everything to dtop202311.

## Key Decisions Made
- **ncps uses upstream image**: `ghcr.io/kalbasit/ncps:v0.9.4` — no build needed. Configured via CLI flags, not TOML. Needs SQLite database migration before serving.
- **ncro is real**: `github.com/manic-systems/ncro` — Nix Cache Route Optimizer. Races upstreams in parallel, EMA latency learning, SQLite route cache, streams NARs without storing them.
- **ncro config format**: TOML with `[[upstreams]]` array (each has `url`, `priority`, optional `public_key`), `[server]` with `listen`, `[cache]` with `ttl` and `negative_ttl`.
- **Harmonia + ncro need building**: No upstream Docker images. Must build from flake.nix on a Nix-capable x86_64-linux machine. User specified: "for x86 you need to build here [dtop202311]. for aarch64 you need to build on oci."
- **garnix-ci is scaffolding**: The role exists but the image build is complex (NixOS VMs, not containers). Needs further investigation before it can be deployed.

## Technical Context

### Stack/Tools
- **Ansible**: Roles using `ansible.builtin.shell` with `DOCKER_HOST: ssh://` and `delegate_to: localhost` (Windows Docker Desktop pattern)
- **Nix Flakes**: For building Harmonia and ncro Docker images
- **Docker**: Containers on Windows Docker Desktop (dtop202311)
- **Traefik**: TLS termination and routing via `proxy_traefik_windows` role
- **Cloudflare DNS**: CNAME records pointing to Tailscale FQDN

### Important Files

**Ansible roles:**
- `shared/active/02-config/ansible/roles/nix-harmonia/` — Harmonia role (serves /nix/store)
- `shared/active/02-config/ansible/roles/nix-ncps/` — ncps role (NAR caching proxy, upstream image)
- `shared/active/02-config/ansible/roles/nix-ncro/` — ncro role (parallel racing proxy)
- `shared/active/02-config/ansible/roles/garnix-ci/` — garnix-ci role (CI builder, scaffolding)

**Nix flakes:**
- `shared/active/03-container/services/artifact/nix-harmonia/flake.nix` — Harmonia Docker image
- `shared/active/03-container/services/artifact/nix-ncro/flake.nix` — ncro Docker image

**Infrastructure:**
- `shared/active/02-config/ansible/infrastructure/ports.yml` — port allocations
- `shared/active/02-config/ansible/infrastructure/domains.yml` — domain names
- `shared/active/02-config/ansible/infrastructure/storage.yml` — volume definitions

**Deployment:**
- `shared/active/02-config/ansible/playbooks/deploy-nix-cache-and-garnix.yml` — main deployment playbook
- `shared/active/02-config/ansible/playbooks/enable-wsl2-kvm.yml` — WSL2 KVM enablement for garnix-ci
- `shared/active/02-config/ansible/playbooks/test-nested-virtualization.yml` — KVM test playbook

**Traefik:**
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/cache-nl-levonk-com.yml.j2`
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/ci-nl-levonk-com.yml.j2`

**Documentation:**
- `shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md` — ADR

**Justfile:**
- `justfile` — targets: `ansible-deploy-nix-cache-garnix`, `ansible-deploy-nix-cache`, `ansible-deploy-garnix-ci`

### Environment Notes
- **dtop202311**: Windows Docker Desktop host, x86_64, accessible via Tailscale SSH (`dtop202311.tale-grouper.ts.net`)
- **nix-sidecar**: Already running on dtop202311, provides shared Nix store at `/nix/store` volume
- **Docker host pattern**: `DOCKER_HOST: ssh://ansible@dtop202311.tale-grouper.ts.net` with `delegate_to: localhost`
- **Vault password**: `~/.ansible/vault_password`
- **Build environment**: Use `devbox run --` for all commands. Source `scripts/ensure-env.sh` first.

### Port Allocations
| Service | Host Port | Container Port | Exposed |
|---------|-----------|----------------|---------|
| Harmonia | 4523 | 5000 | Internal only (127.0.0.1) |
| ncps | 4524 | 8080 | External via Traefik (cache.nl.levonk.com) |
| ncro | 4525 | 8081 | Internal only (127.0.0.1) |
| garnix-ci web | 4526 | 3000 | External via Traefik (ci.nl.levonk.com) |
| garnix-ci API | 4527 | 8080 | External via Traefik (ci.nl.levonk.com) |

## Next Steps (Priority Order)
1. Build Harmonia Docker image on dtop202311 (x86_64-linux) using existing flake.nix
2. Build ncro Docker image on dtop202311 (x86_64-linux) using new flake.nix
3. Deploy the Nix cache chain (Harmonia + ncps + ncro) to dtop202311
4. Verify the cache chain works (test with `nix flake check` or similar)
5. Investigate garnix-ci containerization strategy (NixOS VM → Docker conversion)
6. Deploy garnix-ci (if containerization is feasible)
7. Test nested virtualization on dtop202311 for garnix-ci KVM support

## Definition of Done

A checkbox-tracked task list. The receiving session maintains these marks as it
works. Each line is one task; do not collapse multiple tasks into one line.

**Mark legend:**
- `[ ]` — task pending (not yet started)
- `[~]` — task in progress (actively being worked)
- `[x]` — task done (verified complete)
- `[!]` — task blocked (cannot proceed; note the blocker inline)

**Maintenance protocol (receiving session):**
1. **Verify in-progress marks.** Before doing anything else, re-check every
   task marked `[~]`. If the work is not actually underway (no evidence in the
   working tree, no running process, no recent edit), demote it back to `[ ]`.
   A stale `[~]` is worse than an unstarted `[ ]` because it hides available
   work from the next agent.
2. **Start the next available task.** Pick the first `[ ]` task in priority
   order. Mark it `[~]` immediately before starting work on it.
3. **Prefer subagents for parallel work.** When two or more `[ ]` tasks are
   independent (no shared file writes, no ordering dependency), launch them as
   parallel `run_subagent` calls rather than working them sequentially — this
   is the expected mode of operation, not an optional optimization. Mark each
   `[~]` before launching so concurrent agents see them as claimed. Do not
   parallelize tasks that touch the same files or depend on each other's
   output — run those sequentially.
4. **Mark done only when verified.** Flip `[~]` → `[x]` only after the task's
   success criteria are met and verified (build passes, test passes, file
   exists, etc.). Never mark `[x]` on intent alone.
5. **Record blockers inline.** When a task cannot proceed, mark it `[!]` and
   append the blocker in parentheses on the same line, e.g.
   `- [!] {task blocked (waiting on upstream API access)}`. Move on to the
   next `[ ]` task — do not stall the whole list on one blocker.
6. **Update the list as work reveals new tasks.** Append newly discovered
   tasks as `[ ]` lines in priority order. Do not silently delete tasks; if a
   task is no longer relevant, mark it `[x]` with a note
   (`- [x] {task} (obsolete: reason)`).

```markdown
- [x] Add infrastructure variables (ports, domains, storage) to shared + levonk files
- [x] Create nix-harmonia Ansible role
- [x] Create nix-ncps Ansible role (upstream ghcr.io/kalbasit/ncps:v0.9.4)
- [x] Create nix-ncro Ansible role (github.com/manic-systems/ncro)
- [x] Create garnix-ci Ansible role (scaffolding)
- [x] Add Traefik routing for cache.nl.levonk.com + ci.nl.levonk.com
- [x] Add DNS CNAME records for cache + ci services
- [x] Create deployment playbook (deploy-nix-cache-and-garnix.yml)
- [x] Add justfile targets for building and deploying
- [x] Create ncro flake.nix + Makefile + README in artifact services
- [x] Update ADR + docs with correct ncro URL (github.com/manic-systems/ncro)
- [x] Commit all infrastructure work (commit 0079aae)
- [ ] Build Harmonia Docker image on dtop202311 (x86_64-linux, use existing flake.nix)
- [ ] Build ncro Docker image on dtop202311 (x86_64-linux, use new flake.nix)
- [ ] Deploy Nix cache chain (Harmonia + ncps + ncro) to dtop202311
- [ ] Verify cache chain: test nix substituter points to cache.nl.levonk.com
- [ ] Investigate garnix-ci containerization (NixOS VM → Docker conversion)
- [ ] Deploy garnix-ci if containerization is feasible
- [ ] Test nested virtualization (KVM) on dtop202311 for garnix-ci
```

## Success Criteria
- `cache.nl.levonk.com/nix-cache-info` returns valid cache info from ncps
- `cache.nl.levonk.com` serves cached NARs (verify with `nix path-info --substituters https://cache.nl.levonk.com`)
- ncro races upstreams and logs route decisions in SQLite
- Harmonia serves local `/nix/store` paths that exist on dtop202311
- All containers show "healthy" status in `docker ps`
- `ci.nl.levonk.com` responds (if garnix-ci is deployed)

## Open Questions/Blockers
- **garnix-ci containerization**: The open-sourced garnix-ci runs as NixOS VMs via nixos-compose. Converting to a Docker container is non-trivial. May need to use a different CI solution (e.g., github-nix-ci from juspay) or run garnix-ci in a VM instead of a container.
- **Harmonia signing key**: Harmonia needs a signing key for the cache. This should be generated and stored in the vault. Check if `nix store generate-secret-key` needs to be run.
- **ncps upstream config**: ncps currently points directly to cache.nixos.org and cache.garnix.io. Should it instead point to ncro as its upstream? The ADR says ncps → ncro → upstreams, but the current ncps config has ncro's URL commented out. Need to decide: does ncps query ncro, or does ncps query upstreams directly (making ncro redundant)?

## Do Not
- Do NOT use `docker compose` for deployment — use Ansible roles only (AGENTS.md invariant)
- Do NOT hardcode ports, IPs, or domains — use infrastructure variables
- Do NOT put secrets in `shared/` directory — use client vault
- Do NOT build x86 images on the Mac (macOS) — build on dtop202311 (x86_64-linux)
- Do NOT build aarch64 images on dtop202311 — build on oci (aarch64-linux)
- Do NOT skip the ncps database migration step (`ncps migrate up`) — ncps will fail to start without it
- Do NOT add AI attribution trailers to commits (no "Generated with Devin", no "Co-Authored-By: Devin")

## Suggested Skills
- **ansible**: Best practices for Ansible automation in infrahub — container-based deployments, vault integration, deprecation-free code
- **git-repository-management**: For committing the handoff document and any subsequent work
- **code-quality-validation**: For validating Ansible syntax and role structure before deployment
- **handoff**: For creating this handoff document (already used)

## Additional Context

### ncps CLI flags (upstream image)
The upstream `ghcr.io/kalbasit/ncps:v0.9.4` image uses CLI flags, not a TOML config file:
```
/bin/ncps serve \
  --cache-hostname=cache.nl.levonk.com \
  --cache-storage-local=/storage \
  --cache-database-url=sqlite:/storage/var/ncps/db/db.sqlite \
  --server-listen=0.0.0.0:8080 \
  --cache-upstream-url=https://cache.nixos.org \
  --cache-upstream-url=https://cache.garnix.io \
  --cache-upstream-public-key=cache.nixos.org-1:... \
  --cache-upstream-public-key=cache.garnix.io:...
```
Database migration must run first: `ncps migrate up --cache-database-url=...`

### ncro config format (TOML)
```toml
[server]
listen = "0.0.0.0:8081"

[[upstreams]]
url = "http://localnet-nix-harmonia:5000"
priority = 10

[[upstreams]]
url = "https://cache.nixos.org"
priority = 20
public_key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="

[cache]
ttl = "2h"
negative_ttl = "15m"
```
ncro is stateless (no NAR storage), but keeps SQLite route cache at `/data/routes.db` (set via `NCRO_DB_PATH` env var).

### Building images on dtop202311
The nix-sidecar container on dtop202311 provides a Nix environment. To build:
1. SSH into dtop202311 (or use `DOCKER_HOST: ssh://ansible@dtop202311.tale-grouper.ts.net`)
2. Copy the flake.nix to the host (or use the existing one in the repo)
3. Run `nix build .#docker-prod` in the service directory
4. Run `docker load < result` to load the image into Docker
5. Tag as `localnet-nix-harmonia:latest` or `localnet-nix-ncro:latest`

### Uncommitted working tree changes
There are other uncommitted changes in the working tree from unrelated work (sandbox-cli-proxy, devbox.json updates, bootstrap scripts). These are NOT part of this handoff. Check `git status` to see them.
