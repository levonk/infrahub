# Levonk Exit Nodes: Build/Deploy Justfiles + Arch Map + SSH Fix

**Date**: 2026-07-30
**Session**: Close the gap that made every prior session stumble on arch/build/deploy for levonk exit nodes
**Status**: In progress — plan confirmed, execution starting

## Current State

### ✅ Completed (this session)
- **Diagnosed why prior sessions stumbled**: AGENTS.md Invariant #2 *does* answer "where to build" (Mac → push to OCI registry `100.90.22.85:5000` → pull on target). The real gaps are: (a) no documented host→arch map, (b) build script defaults to arm64 only with manual `PLATFORM=` override, (c) no build→deploy wired recipes, (d) deploy recipes don't build first.
- **Diagnosed Mac password prompts**: `ssh-add -l` → "The agent has no identities." SSH config for `dtop202311.tale-grouper.ts.net` lacks `UseKeychain yes` / `AddKeysToAgent yes`, so the passphrase-protected key `~/.ssh/lzkmbp2016-micro-oracle` re-prompts on every Ansible SSH task.
- **Confirmed buildx available**: `docker buildx v0.33.0`, `orbstack` builder supports `linux/amd64` + `linux/arm64`. Can do true multi-arch in one `docker buildx build --platform linux/amd64,linux/arm64 --push` (kills the legacy-builder deprecation warning and the manual manifest hack).
- **Confirmed no `levonk/justfile` exists** — needs creating.
- **Confirmed SERVICES.md is auto-generated** by `shared/active/02-config/ansible/scripts/generate_service_catalog.py` from `infrastructure/*.yml`; the `MACHINES` dict (lines 42–67) holds per-machine metadata and is the place to add an `arch` field.

### ❌ Blocking Issues
1. **Uncommitted prior-session changes** in both parent and submodule (see Files Modified below) — must be reviewed/committed before clean deployment.
2. **cno (OCI) state**: `nordvpn` healthy; `tailscale-nordvpn` running but Tailscale node OFFLINE 6d (NAT masquerading never applied); `tailscale-tor` running/online; `tor-exit` container MISSING.
3. **nl (Windows) state**: host ONLINE; no exit-node containers running; orphaned networks `vpn-network-windows` + `tor-network-windows` need cleanup.

## Project Overview

### Objective
Make levonk exit-node deployment a single, repeatable `just` command per network — build the right images for the right arch, push to registry, deploy — with no agent guessing about architectures or build locations. Generalize the pattern so all levonk services eventually get build+deploy targets.

### User Decisions (this session)
- **Rollout scope**: Exit nodes end-to-end first; expand to all 44 services afterward.
- **Parent justfile**: **Remove** client-specific recipes entirely (no aliases). Client recipes live only in `levonk/justfile`. Matches the "shared/ must be client-agnostic" rule.
- **Host-arch map**: Surface arch in `levonk/SERVICES.md` (via the generator) AND a source `infrastructure/hosts.yml`.
- **Build tool**: Switch to `docker buildx` for native multi-arch (no warning, no manifest hack).
- **Stale check**: Deploy calls build if the image's `ctxhash` is stale (reuse existing hash logic).
- **Document first**: Run handoff skill before executing.

## Key Decisions Made
- **Build on Mac, push to OCI registry, pull on target** — AGENTS.md Invariant #2 (already the rule; prior sessions violated it with ad-hoc `docker build`/manifest dances).
- **cno/oci = arm64, nl/dtop202311 = amd64** — encoded once in `infrastructure/hosts.yml` + generator `MACHINES` dict, never re-derived by agents.
- **Only 2 locally-built images for exit nodes**: `localnet-base-alpine`, `localnet-proxy-tor`. NordVPN uses upstream `gluetun`; Tailscale uses upstream `tailscale/tailscale` (both multi-arch on Docker Hub, no build needed).
- **levonk/justfile is the source of truth** for all `levonk-*` recipes; parent justfile drops `ansible-deploy-vpn`, `ansible-deploy-nordvpn`, `ansible-deploy-windows-exit-nodes`, `ansible-deploy-worldmonitor`, `ansible-deploy-base-dev`, `ansible-deploy-rustfs`, `ansible-deploy-wazuh`, etc.

## Technical Context

### Stack/Tools
- Ansible + `community.docker` modules (Invariant #4: never `docker compose`/`docker run` via shell)
- `docker buildx` v0.33.0 (orbstack builder, amd64+arm64)
- Local registry: `100.90.22.85:5000` (OCI, over Tailscale)
- just (task runner), devbox (env)
- Windows Docker Desktop targets reached via `docker_host: ssh://ansible@dtop202311.tale-grouper.ts.net` + `delegate_to: localhost` (community.docker modules can't run ON Windows due to `grp` import)

### Important Files
- `scripts/build-and-push-images.sh` — current builder; defaults `PLATFORM=linux/arm64`, uses legacy `docker build --platform` (deprecation warning). **Rewrite to buildx multi-arch.**
- `justfile` (parent) — has client-specific recipes to remove (lines ~325–528).
- `shared/active/02-config/ansible/scripts/generate_service_catalog.py` — `MACHINES` dict (lines 42–67) needs `arch` field; emit in Machine Legend + Machine Reference.
- `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/` — Windows NordVPN role (refactored to community.docker in prior session).
- `shared/active/02-config/ansible/roles/vpn-tor-windows/` — Windows Tor role (refactored in prior session).
- `shared/active/02-config/ansible/roles/vpn-tailscale/` — Tailscale sidecar role (cno).
- `levonk/active/02-config/ansible/inventories/oci.yml` — cno inventory (modified, uncommitted).
- `~/.ssh/config` — `dtop202311.tale-grouper.ts.net` host block needs `UseKeychain yes` + `AddKeysToAgent yes`.

### Environment Notes
- Mac is the control/build machine (orbstack Docker).
- SSH agent currently empty — must `ssh-add --apple-use-keychain ~/.ssh/lzkmbp2016-micro-oracle` after fixing `~/.ssh/config`.

## Next Steps (Priority Order)
1. **Fix SSH password prompts**: edit `~/.ssh/config` (add `UseKeychain yes`/`AddKeysToAgent yes` to dtop202311 + oci blocks), then `ssh-add --apple-use-keychain ~/.ssh/lzkmbp2016-micro-oracle`. Verify `ssh-add -l` shows the key and SSH to dtop202311 is passphrase-free.
2. **Add host→arch map**: create `levonk/active/02-config/ansible/infrastructure/hosts.yml`; add `arch` to `MACHINES` dict in `generate_service_catalog.py`; regenerate `levonk/SERVICES.md`.
3. **Rewrite `build-and-push-images.sh` to buildx**: `docker buildx build --platform linux/amd64,linux/arm64 -t <registry>/<image>:latest --push`. Remove single-PLATFORM default + manual manifest logic.
4. **Create `levonk/justfile`**: `levonk-build-exit-nodes` (builds `localnet-base-alpine` + `localnet-proxy-tor` multi-arch, pushes), `levonk-deploy-exit-nodes-cno` (build-if-stale → deploy via `cloud-server-vpn.yml`), `levonk-deploy-exit-nodes-nl` (build-if-stale → deploy via `deploy-windows-exit-nodes.yml` + cleanup orphaned networks).
5. **Remove client-specific recipes from parent `justfile`**.
6. **Review/commit prior-session uncommitted changes** (parent + submodule) before deploying.
7. **Deploy cno**: fix NordVPN Tailscale (NAT masquerading), restore `tor-exit`, rename containers to `vpn-tailscale-exit` / `tor-tailscale-exit`.
8. **Deploy nl**: cleanup orphaned networks, deploy exit nodes with correct amd64 images.
9. **Verify both networks**; regenerate SERVICES.md; final commit.

## Success Criteria
- ✅ `ssh-add -l` shows the oracle key; SSH to dtop202311 no longer prompts for passphrase.
- ✅ `just levonk-build-exit-nodes` builds `localnet-base-alpine` + `localnet-proxy-tor` for both arches and pushes to registry — no deprecation warning.
- ✅ `just levonk-deploy-exit-nodes-cno` and `just levonk-deploy-exit-nodes-nl` each build-if-stale then deploy, end-to-end, single command.
- ✅ `levonk/SERVICES.md` Machine Legend shows arch per machine.
- ✅ Parent `justfile` contains no client-specific deploy recipes.
- ✅ cno: NordVPN Tailscale online, `tor-exit` present, containers renamed.
- ✅ nl: exit nodes running, no orphaned `-windows` networks, host stays online.

## Open Questions/Blockers
- **Prior uncommitted changes** (e.g. `cloud-server-vpn.yml`, `vpn-tailscale/tasks/main.yml`, `paperclip/Dockerfile`, `tor/entrypoint-service.sh`, submodule `oci.yml`) — need user confirmation on whether to commit as-is or review first.
- **nl Tailscale-in-Docker root cause** (WSL2 + Docker Desktop + Tailscale, GitHub #17538) — mitigation: deploy one container at a time with host connectivity monitoring; ensure host Tailscale does NOT use container exit nodes.

## Do Not
- ❌ Build images on the target host (Invariant #2).
- ❌ Use `docker compose` or `docker run` via shell (Invariant #4).
- ❌ Hand-edit `levonk/SERVICES.md` — it is generated; edit the generator/infra files and run `just generate-service-catalog`.
- ❌ Re-derive architectures per session — read `infrastructure/hosts.yml`.
- ❌ Put client-specific recipes in the parent `justfile`.
- ❌ Add `-windows` suffix to network/container/volume names (ADR-20260719002).
- ❌ Convert the `levonk/` submodule to a regular directory.

## Suggested Skills
- **handoff** — used this session to capture the plan; update this doc as work progresses.
- **ansible** — Ansible best practices for the role/playbook edits and deployment.
- **git-repository-management** — for organizing/committing the prior-session changes + this work.

## Additional Context
- **Project**: infrahub (levonk client submodule)
- **ADR compliance**: ADR-20260719002 (naming: no `-windows` suffix), ADR-20260624001 (secrets in client vault), ADR-20260625001 (infra consolidation)
- **Git workflow**: commit in `levonk/` submodule first, then update submodule ref in parent
- **Prior handoffs**: `.agents/handoffs/2026/07/202607290620-windows-exit-nodes-rename-and-fix.md` (rename + fix context)

## Files Modified This Session
- `/Users/micro/.claude/skills/handoff/SKILL.md` — updated `last-used` to 2026-07-30
- `.agents/handoffs/2026/07/202607300043-levonk-exit-nodes-build-deploy-justfiles.md` — this document

### Pre-existing uncommitted changes (from prior sessions, to review)
- Parent: `shared/.../playbooks/cloud-server-vpn.yml`, `shared/.../roles/vpn-tailscale/tasks/main.yml`, `shared/.../services/ai-codeassist/paperclip/Dockerfile`, `shared/.../services/proxy/tor/entrypoint-service.sh`, `shared/.../internal-docs/todo/todo-priorities.md`, `levonk` submodule ref, `internal-docs/feature/2026/07/sidecar-modernize-deploy/` (untracked)
- Submodule: `active/02-config/ansible/inventories/oci.yml`
