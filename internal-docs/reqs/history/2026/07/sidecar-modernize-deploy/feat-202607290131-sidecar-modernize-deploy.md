---
# Product Requirements Document (PRD)

## Introduction / Overview

- **Feature name:** Sidecar Modernization and Multi-Target Deployment
- **Summary:** Modernize three legacy sidecar containers (nx-sidecar, pnpm-sidecar, nix-sidecar) to current container-best-practices standards, then deploy them to three machine types (macOS, OCI cloud server, OCI isolation VM) via shared Ansible roles.
- **Context:**
  - The three sidecars currently live under `shared/active/03-container/services/` with Dockerfiles, entrypoints, healthchecks, and Nx `project.json` files. They are built for x86_64-linux only and deployed (only nix-sidecar) via the isolation-VM-specific role `isolation-vm-containers`.
  - The knowledge base at `skills-src/build/current/knowledge/container-best-practices/` defines modern standards: image digest pinning, multi-stage builds, multi-arch builds, runtime hardening (non-root, cap-drop, no-new-privileges), hadolint CI, `.dockerignore`, and `apk add --no-cache` with cleanup.
  - The OCI cloud server is ARM (aarch64), not x86. The isolation VM is also ARM (Debian arm64). The macOS hosts are x86 but run Docker Desktop/OrbStack with a linux/amd64 VM. Multi-arch (linux/amd64 + linux/arm64) is mandatory.
  - The workflow `do-new-srvc-infrahub.md` was run; user decisions captured below.

## Goals

1. Modernize all three sidecar Dockerfiles to comply with `container-best-practices` knowledge base.
2. Build multi-arch images (linux/amd64 + linux/arm64) via GitHub Actions CI, pushed to both the local registry (100.90.22.85:5000) and GHCR (ghcr.io) as a mirror.
3. Create three shared Ansible roles (`sidecar-nix`, `sidecar-pnpm`, `sidecar-nx`) that deploy each sidecar to any target host group via `community.docker` modules.
4. Deploy all three sidecars to the levonk client environment on three machine types: `macos_hosts` (lzkmbp2016, lzkmbp2018), `cloud_servers` (oci-cloud-server), `isolation_vms` (isolation-vm).
5. Extract nix-sidecar from the `isolation-vm-containers` role into its own shared role without breaking existing isolation-VM consumers.

## User Stories

- **As a developer**, I want the nix-sidecar, pnpm-sidecar, and nx-sidecar available on my Mac so I can build containers locally with shared Nix/pnpm/Nx caches.
- **As a developer**, I want the same sidecars on the OCI cloud server and isolation VM so build caches are consistent across all build environments.
- **As an operator**, I want the sidecar images built multi-arch in CI so ARM and x86 hosts both get the correct architecture without manual builds.
- **As an operator**, I want the sidecars hardened (non-root where possible, cap-drop, no-new-privileges) so a container escape has minimal blast radius.
- **As a maintainer**, I want the sidecar Dockerfiles to pass hadolint so CI catches regressions automatically.

## Functional Requirements

### FR-1: Dockerfile Modernization

- **FR-1.1**: Pin all `FROM` lines to image digests (`@sha256:...`), not just tags. Applies to `localnet-base-sidecar`, `nixpkgs/nix`, and any other base images.
- **FR-1.2**: Use `apk add --no-cache` and add `rm -rf /var/cache/apk/*` cleanup in final stages (where not already using BuildKit cache mounts).
- **FR-1.3**: Add `.dockerignore` to each sidecar directory to exclude `.git`, `doc/`, `tests/`, and other non-build files from the build context.
- **FR-1.4**: Convert nx-sidecar to multi-stage build with archive pattern (build nx package in builder stage, archive with zstd, extract in entrypoint to shared volume). Currently it installs nx at runtime via pnpm — move to build-time archive.
- **FR-1.5**: Fix pnpm-sidecar healthcheck shebang: currently `#!/bin/bash` but the image is Alpine (no bash). Change to `#!/bin/sh`.
- **FR-1.6**: Simplify nix-sidecar entrypoint (currently 571 lines). Bake coreutils and ripgrep into the image at build time instead of installing them at runtime via `nix profile install`. The entrypoint should only handle: (a) bootstrap tarball extraction if /nix/store is empty, (b) nix.conf setup, (c) exec the main process.
- **FR-1.7**: Add `LABEL` metadata to each Dockerfile (org.opencontainers.image.title, source, version).

### FR-2: Multi-Arch Build Pipeline

- **FR-2.1**: Create a GitHub Actions workflow (`.github/workflows/sidecar-build.yml`) that builds all three sidecars for `linux/amd64,linux/arm64` using `docker buildx build --push`.
- **FR-2.2**: Push to both the local registry (`100.90.22.85:5000/localnet-{sidecar}:latest`) and GHCR (`ghcr.io/levonk/localnet-{sidecar}:latest`). Use a matrix or multi-push step.
- **FR-2.3**: Use native amd64 and arm64 GitHub Actions runners (not QEMU) to avoid the 10-24x slowdown and Rust/C++ segfault risk documented in `container-runtime-essentials.md`.
- **FR-2.4**: Run `hadolint` on each Dockerfile as a CI gate before the build step.
- **FR-2.5**: Tag images with both `:latest` and `:sha-<git-sha>` for traceability.

### FR-3: Shared Ansible Roles

- **FR-3.1**: Create `shared/active/02-config/ansible/roles/sidecar-nix/` — shared role for nix-sidecar deployment. Variable-driven (image name, volume paths, network, resource limits, healthcheck timing). Works on Linux and macOS.
- **FR-3.2**: Create `shared/active/02-config/ansible/roles/sidecar-pnpm/` — shared role for pnpm-sidecar deployment.
- **FR-3.3**: Create `shared/active/02-config/ansible/roles/sidecar-nx/` — shared role for nx-sidecar deployment. Depends on pnpm-sidecar being deployed (shared volume).
- **FR-3.4**: Each role uses `community.docker.docker_container`, `docker_network`, `docker_volume`, `docker_image` modules only — never `docker compose` or `ansible.builtin.shell: docker ...`.
- **FR-3.5**: Each role has `defaults/main.yml` with neutral defaults, `tasks/main.yml` orchestrating task includes, and `meta/main.yml` with proper role naming (`sidecar_nix`, `sidecar_pnpm`, `sidecar_nx`).
- **FR-3.6**: Extract nix-sidecar tasks from `isolation-vm-containers/tasks/nix-sidecar.yml` into the new `sidecar-nix` role. Update `isolation-vm-containers` to depend on `sidecar-nix` role instead of inlining the tasks. Verify isolation-VM deployment still works.
- **FR-3.7**: Each role includes a `verify` tag and `<service>_verify_health` flag for role-level validation per the Ansible AGENTS.md.

### FR-4: Runtime Hardening

- **FR-4.1**: nx-sidecar and pnpm-sidecar: run as non-root (USER 1000), cap-drop ALL, no-new-privileges, read-only root fs with tmpfs for writable dirs.
- **FR-4.2**: nix-sidecar: keep root USER (required for multi-user Nix store ownership) but remove `privileged: true`. Use `cap_drop: [ALL]` with specific `cap_add` only for what Nix needs. Set `security_opts: [no-new-privileges:true]`. Document the exception per the hardening checklist.
- **FR-4.3**: All three: resource limits (mem_limit, cpus, pids_limit) set via Ansible variables.

### FR-5: Deployment Playbook

- **FR-5.1**: Create `shared/active/02-config/ansible/playbooks/deploy-sidecars.yml` that targets a host group variable and includes the three sidecar roles.
- **FR-5.2**: Create `shared/active/02-config/ansible/playbooks/validate-sidecars.yml` for post-deployment validation (read-only checks: container running, healthy, no errors in logs).
- **FR-5.3**: Add `just ansible-deploy-sidecars` and `just ansible-validate-sidecars` recipes.
- **FR-5.4**: Deploy to `macos_hosts`, `cloud_servers`, and `isolation_vms` host groups in the levonk client environment.

### FR-6: Infrastructure Variables

- **FR-6.1**: Add sidecar-related variables to `shared/active/02-config/ansible/infrastructure/ports.yml` (if any host ports are needed — sidecars typically don't expose ports).
- **FR-6.2**: Add volume/storage paths to `shared/active/02-config/ansible/infrastructure/storage.yml` following the `infra_storage_{service}_*` naming convention.
- **FR-6.3**: Add network names to `shared/active/02-config/ansible/infrastructure/networks.yml` if new networks are needed.
- **FR-6.4**: No hardcoded IPs, ports, or paths in roles or playbooks — all via `infra_*` variables.

## Non-Functional Requirements

- **NFR-1 (Security)**: No secrets in the `shared/` directory. No secrets in sidecar images. All secrets via vault.
- **NFR-2 (Reproducibility)**: Image digests pinned. CI builds are reproducible from a given commit.
- **NFR-3 (Performance)**: Sidecar startup under 60s (nx, pnpm) and under 300s (nix — bootstrap tarball extraction). Archive pattern prevents re-downloading on every container start.
- **NFR-4 (Portability)**: Images work on linux/amd64 and linux/arm64. Roles work on macOS (Docker Desktop/OrbStack/Apple Container), Oracle Linux, and Debian.
- **NFR-5 (Maintainability)**: Dockerfiles pass hadolint. Ansible roles pass ansible-lint. Entry points under 100 lines (nix-sidecar currently 571 — must be reduced).
- **NFR-6 (Idempotency)**: Ansible roles are idempotent — running twice produces no changes on the second run.

## Current State

### Relevant files and their roles

- `shared/active/03-container/services/artifact/nx-sidecar/Dockerfile.nx-sidecar` — single-stage, installs nodejs/npm/zstd via apk, no archive pattern, no digest pinning
- `shared/active/03-container/services/artifact/nx-sidecar/assets/static/nx-sidecar/entrypoint-nx-sidecar.sh` — 62 lines, installs nx at runtime via pnpm, creates cache dirs
- `shared/active/03-container/services/artifact/nx-sidecar/assets/static/nx-sidecar/healthcheck-nx.sh` — 38 lines, checks cache dirs + nx command
- `shared/active/03-container/services/artifact/nx-sidecar/project.json` — Nx project config, `docker:build` and `docker:up` targets
- `shared/active/03-container/services/artifact/nx-sidecar/flake.nix` — hardcoded `x86_64-linux`
- `shared/active/03-container/services/artifact/pnpm-sidecar/Dockerfile.pnpm-sidecar` — multi-stage with archive pattern (zstd -19), but no digest pinning, no .dockerignore
- `shared/active/03-container/services/artifact/pnpm-sidecar/assets/static/pnpm-sidecar/entrypoint-pnpm-sidecar.sh` — 50 lines, extracts archive to shared volume
- `shared/active/03-container/services/artifact/pnpm-sidecar/assets/static/pnpm-sidecar/healthcheck-pnpm.sh` — **BUG**: `#!/bin/bash` shebang but Alpine has no bash
- `shared/active/03-container/services/artifact/pnpm-sidecar/project.json` — Nx project config
- `shared/active/03-container/services/artifact/pnpm-sidecar/flake.nix` — hardcoded `x86_64-linux`
- `shared/active/03-container/services/base/nix-sidecar/Dockerfile.nix-sidecar` — 3-stage (busybox-builder, bootstrap-builder, final), uses `nixpkgs/nix:latest` (unpinned), no .dockerignore
- `shared/active/03-container/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh` — **571 lines**, installs coreutils + ripgrep at runtime via `nix profile install`, overly complex
- `shared/active/03-container/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh` — 476 lines, comprehensive but excessive for a healthcheck
- `shared/active/03-container/services/base/nix-sidecar/project.json` — Nx project config
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/nix-sidecar.yml` — current nix-sidecar deployment (81 lines), uses `privileged: true`, embedded in isolation-VM role
- `shared/active/02-config/ansible/roles/isolation-vm-containers/defaults/main.yml` — nix-sidecar defaults mixed with isolation-VM-specific defaults
- `shared/active/03-container/services/artifact/AGENTS.md` — documents the archive pattern for sidecars
- `shared/active/03-container/AGENTS.md` — documents that docker-compose is deprecated, Ansible is the deployment method

### Existing code excerpts

**nix-sidecar privileged deployment (to be extracted):**
`shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/nix-sidecar.yml:39`:
```yaml
    privileged: true
```
This must become `cap_drop: [ALL]` with specific `cap_add` in the new shared role.

**pnpm healthcheck shebang bug:**
`shared/active/03-container/services/artifact/pnpm-sidecar/assets/static/pnpm-sidecar/healthcheck-pnpm.sh:1`:
```bash
#!/bin/bash
```
Must be `#!/bin/sh` (Alpine has no bash).

**Hardcoded architecture in flakes:**
`shared/active/03-container/services/artifact/nx-sidecar/flake.nix:10`:
```nix
system = "x86_64-linux";
```
All three flakes have this — must support `aarch64-linux` too.

### Repository conventions

- **Container deployment**: Use `community.docker` modules, never `docker compose`. See `shared/active/02-config/ansible/AGENTS.md`.
- **Role naming**: `common-{platform}-{concern}-hardening` for hardening roles; functional-group prefixes (`sidecar-`) for service roles. `role_name` in `meta/main.yml` uses underscores.
- **Infrastructure variables**: `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}` naming. See root `AGENTS.md` "Infrastructure Consolidation Strategy".
- **Secret storage**: Per-client vault in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`. Never in `shared/`.
- **Sidecar archive pattern**: Multi-stage build with zstd archive, entrypoint extracts to shared volume. See `shared/active/03-container/services/artifact/AGENTS.md`.
- **Devbox usage**: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {COMMAND}` for all tool invocations.
- **Vault edits**: Agent provides docker run command for user to edit vault interactively. Agent never edits vault directly.
- **Container best practices knowledge base**: `~/p/gh/levonk/skills-src/build/current/knowledge/container-best-practices/` — authoritative reference for all Dockerfile/container decisions.

### Design constraints

- **OCI is ARM**: `host_vars/oci-cloud-server.yml:82` — "OCI ARM instance (aarch64) does NOT support nested KVM". Images must be arm64-compatible.
- **Isolation VM is ARM**: `host_vars/oci-cloud-server.yml:133` — `isolation_vm_debian_arch: "arm64"`.
- **macOS container runtime**: `group_vars/macos_hosts.yml:16` — `macos_container_runtime: "auto"` (Apple Container on macOS 26+ ARM, OrbStack otherwise). Roles must work with both.
- **nix-sidecar multi-user Nix**: The healthcheck (`healthcheck-nix-sidecar.sh:6-10`) documents that it expects multi-user Nix (root:nixbld, 2775 perms, nixbld group GID 30000). Refactoring to single-user would break this contract.
- **Local registry**: `100.90.22.85:5000` — already used by `isolation-vm-containers/defaults/main.yml:18`.

## Technical Considerations

### Multi-arch build strategy

GitHub Actions with native runners:
- `ubuntu-latest` runner → builds `linux/amd64` natively
- `ubuntu-24.04-arm` (or `oracle-cloud-arm`) runner → builds `linux/arm64` natively
- Use `docker buildx imagetools create` to merge per-arch images into a single multi-arch manifest, or use a single `buildx build --platform linux/amd64,linux/arm64` job if QEMU is acceptable for the lighter sidecars (nx, pnpm — no compilation). For nix-sidecar (builds BusyBox from source), use per-arch native builds and merge.

### nix-sidecar root/privileged trade-off

The nix-sidecar requires root for:
- `/nix/store` ownership (root:nixbld, 2775)
- nixbld group management (GID 30000)
- nix daemon (multi-user mode)

Decision: Keep root USER, remove `privileged: true`, use `cap_drop: [ALL]` with `cap_add: [CHOWN, SETGID, SETUID]` (needed for store ownership). Add `security_opts: [no-new-privileges:true]`. Document as a justified exception per `container-runtime-hardening.md` checklist.

### Role extraction from isolation-vm-containers

The `isolation-vm-containers` role currently has `tasks/nix-sidecar.yml` with isolation-VM-specific variable names (`isolation_vm_nix_sidecar_*`). The extraction:
1. Create `sidecar-nix` role with generic variable names (`sidecar_nix_*`)
2. In `isolation-vm-containers/defaults/main.yml`, map `isolation_vm_nix_sidecar_*` → `sidecar_nix_*` via variable overrides
3. In `isolation-vm-containers/tasks/main.yml`, replace `include_tasks: nix-sidecar.yml` with `include_role: sidecar-nix`
4. Delete `isolation-vm-containers/tasks/nix-sidecar.yml`
5. Verify isolation-VM deployment still works via `just ansible-deploy-vms`

## Verification Approach

| Purpose | Command | Expected Result |
|---------|---------|-----------------|
| Dockerfile lint | `hadolint Dockerfile.*-sidecar` | exit 0, no errors |
| Ansible lint | `devbox run -- rtk ansible-lint roles/sidecar-*/` | exit 0 |
| Ansible syntax | `devbox run -- rtk ansible-playbook --syntax-check playbooks/deploy-sidecars.yml` | exit 0 |
| Ansible check mode | `devbox run -- rtk ansible-playbook --check -i levonk/.../oci.yml playbooks/deploy-sidecars.yml` | no errors |
| Multi-arch build | `docker manifest inspect ghcr.io/levonk/localnet-nix-sidecar:latest` | shows amd64 + arm64 |
| Deploy to OCI | `just ansible-deploy-sidecars` (targeting cloud_servers) | containers running, healthy |
| Deploy to Mac | `just ansible-deploy-sidecars` (targeting macos_hosts) | containers running, healthy |
| Deploy to VM | `just ansible-deploy-sidecars` (targeting isolation_vms) | containers running, healthy |
| Validate | `just ansible-validate-sidecars` | all checks pass |
| Isolation VM regression | `just ansible-deploy-vms` | nix-sidecar still deploys via new role |

## Success Criteria (Machine-Checkable)

- [ ] `hadolint` passes on all three modernized Dockerfiles
- [ ] `ansible-lint` passes on all three new sidecar roles
- [ ] `ansible-playbook --syntax-check` passes on `deploy-sidecars.yml` and `validate-sidecars.yml`
- [ ] `docker manifest inspect` shows both `amd64` and `arm64` for all three images on GHCR
- [ ] All three sidecar containers reach "healthy" state on OCI cloud server after deployment
- [ ] All three sidecar containers reach "healthy" state on at least one macOS host after deployment
- [ ] All three sidecar containers reach "healthy" state on isolation VM after deployment
- [ ] `just ansible-deploy-vms` still succeeds (no regression in isolation-VM nix-sidecar deployment)
- [ ] nix-sidecar entrypoint is under 100 lines (down from 571)
- [ ] No hardcoded IPs, ports, or paths in new roles or playbooks
- [ ] pnpm-sidecar healthcheck uses `#!/bin/sh` (not `#!/bin/bash`)

## Out of Scope

- **Other sidecars**: Only nx-sidecar, pnpm-sidecar, and nix-sidecar are in scope. The other ~20 sidecars (rust, dotnet, conda, etc.) are not modernized in this feature.
- **Apple Silicon macOS support**: The macOS hosts are currently x86. Apple Container native support for ARM macs is noted in group_vars but not tested in this feature.
- **Nix flake container builds**: The `container-runtime-essentials.md` knowledge base mentions Nix flake containers (`dockerTools.buildLayeredImage`) as an alternative to Dockerfiles. We are keeping Dockerfiles for portability — not converting to Nix flake container builds.
- **Sidecar web UIs/dashboards**: No web interfaces for the sidecars. They are headless build-cache containers.
- **Backup/restore of shared volumes**: Volume data persistence is handled by Docker volumes. Backup strategy is a separate feature.

## Risk Assessment

- **Priority:** P2
- **Effort:** L
- **Risk:** MED

### Key risks

1. **nix-sidecar root refactor** — removing `privileged: true` may break Nix store operations if the capability set is insufficient. Mitigation: test on isolation VM first (already has nix-sidecar), verify `nix build` works inside the container.
2. **Role extraction regression** — extracting nix-sidecar from `isolation-vm-containers` could break the existing isolation-VM deployment. Mitigation: keep variable mapping in `isolation-vm-containers/defaults/main.yml`, run `just ansible-deploy-vms` as a regression test.
3. **macOS container runtime variance** — Docker Desktop, OrbStack, and Apple Container have different behaviors with volumes and networks. Mitigation: test on lzkmbp2016 (OrbStack) first; Apple Container can be a follow-up.
4. **GHCR auth** — pushing to GHCR requires a PAT in the GitHub Actions secrets. Mitigation: user must provide the token; agent provides the exact secret name needed.
5. **Multi-arch nix-sidecar build** — BusyBox compilation from source via Nix may fail on arm64 if the Nix flake has arch-specific issues. Mitigation: use `nixos-25.11` (already pinned in the Dockerfile comment), test arm64 build in CI before merging.

## Success Metrics

- All three sidecar images available multi-arch on GHCR and local registry
- Sidecar startup time: nx < 30s, pnpm < 30s, nix < 300s (with bootstrap extraction)
- Zero regression in isolation-VM nix-sidecar deployment
- hadolint and ansible-lint pass in CI

## Open Questions

- None remaining. All decisions captured in the user's answers to clarifying questions.

## Dependencies

- **GitHub Actions ARM runner**: GitHub provides `ubuntu-24.04-arm` runners (or use Oracle Cloud ARM as a self-hosted runner). Confirm availability.
- **GHCR authentication**: A GitHub PAT with `write:packages` scope must be in repository secrets as `GHCR_TOKEN`.
- **Local registry availability**: The OCI server's registry at `100.90.22.85:5000` must be running and reachable from GitHub Actions (via Tailscale or public endpoint). If not reachable from GitHub Actions, push to GHCR only and have target hosts pull from GHCR.
- **Docker buildx**: Must be available in the GitHub Actions runner (pre-installed on `ubuntu-latest`).

## Timeline / Milestones

1. **M1: Dockerfile modernization** — Modernize all 3 Dockerfiles + entrypoints + healthchecks. Add .dockerignore. Fix pnpm shebang bug. Reduce nix entrypoint to <100 lines.
2. **M2: CI pipeline** — GitHub Actions workflow for multi-arch builds + hadolint gate. Push to GHCR + local registry.
3. **M3: Shared Ansible roles** — Create `sidecar-nix`, `sidecar-pnpm`, `sidecar-nx` roles. Extract from `isolation-vm-containers`.
4. **M4: Deployment playbook** — `deploy-sidecars.yml` + `validate-sidecars.yml` + just recipes.
5. **M5: Deploy + verify** — Deploy to macos_hosts, cloud_servers, isolation_vms. Verify healthy. Run regression test on isolation VM.

## Maintenance Notes

- **Future sidecar modernization**: The pattern established here (shared role per sidecar, multi-arch CI, archive pattern) should be applied to other sidecars when they are modernized.
- **ARM mac support**: When Apple Silicon macs are added to `macos_hosts`, the multi-arch images will already support arm64. The roles may need testing with Apple Container runtime.
- **Digest updates**: When base images (`localnet-base-sidecar`, `nixpkgs/nix`) are updated, the digest pins in the Dockerfiles must be updated. CI should have a scheduled job to check for base image updates.
- **Reviewers should scrutinize**: the nix-sidecar capability set (cap_add list) — too few caps will break Nix, too many defeats the hardening.

## STOP Conditions

Stop and report back (do not improvise) if:
- The nix-sidecar fails to build multi-arch in CI (BusyBox compilation issue on arm64)
- Removing `privileged: true` from nix-sidecar breaks `nix build` inside the container
- The `isolation-vm-containers` role extraction breaks the existing isolation-VM deployment
- GHCR authentication cannot be set up (no PAT available)
- The local registry is not reachable from GitHub Actions
- A macOS container runtime (OrbStack/Apple Container) does not support the required volume/network features
- The code at the documented locations doesn't match the excerpts (files have changed since PRD creation)

---
*Generated from PRD template*
