---
modeline: "vim: set ft=markdown:"
title: "ADR: Container Build Strategy for Mixed-Architecture Fleets"
adr-id: "adr-20260709001"
slug: "container-build-strategy-mixed-arch"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-20260709001-container-build-strategy-mixed-arch.md"
synopsis: "Adopt a three-branch image sourcing decision tree (pre-built → Dockerfile+buildx → Nix flake) with mandatory multi-arch builds for the mixed x86_64/aarch64 fleet, and require build feasibility checks before creating implementation tasks."
author: "https://github.com/levonk"
date-created: "2026-07-09"
date-updated: "2026-07-09"
date-review: "2027-01-09"
date-triggers: ["2026-10-09"]
version: "0.1.0"
status: "accepted"
aliases: ["ADR-20260709001"]
tags: [doc/architecture/adr, container, multi-arch, buildx, nix, docker]
supersedes: []
superseded-by: []
related-to: ["nix-cache-chain-regional-parallel-racing", "infrastructure-consolidation"]
scope:
  impact-scope: [all-containerized-services, build-hosts, ci-pipeline, ansible-roles]
  excluded-scope: [kubernetes-manifests, bare-metal-services]
---

# Decision Record: Container Build Strategy for Mixed-Architecture Fleets

**Filename:** `adr-20260709001-container-build-strategy-mixed-arch.md`

- belongs in `shared/active/08-docs/adr/` (existing repo convention)

---

## Context

The fleet spans multiple CPU architectures: x86_64 machines (dtop202311 WSL2,
isolation-vm) and aarch64 machines (OCI cloud server, x86_64 Mac, aarch64 Mac).
Build hosts are similarly mixed: macOS (darwin, both x86_64 and aarch64),
Windows WSL2 (x86_64 Linux), OCI cloud (aarch64 Linux). No single machine
can natively build container images for all target architectures.

During the nix-cache-chain implementation (ADR-20260708001), we spent hours
trying to build 4 Nix cache service container images from Nix flakes. The
experience revealed systemic issues:

1. **Nix flakes hardcoded `system = "x86_64-linux"`** — could only build on
   x86_64 Linux. No single machine could build all images natively.
2. **Desperate workarounds**: QEMU/binfmt emulation (Rust `mold` linker
   segfaults), building inside `nixos/nix` Docker containers on macOS (4-hour
   builds), SSH-ing to various machines, trying Nix distributed builds.
3. **Architecture-mismatched images**: Harmonia built as aarch64 on OCI (can't
   run on x86_64), Attic built as x86_64 in Docker on Mac (can't run on
   aarch64 OCI). Single-arch `:latest` tags meant hosts pulled wrong arch.
4. **Never checked for pre-built upstream images first.** Two of four services
   (Attic, ncps) had official multi-arch Docker images on GHCR. Hours of
   source building when `docker pull && docker tag && docker push` would have
   sufficed.
5. **Nix flake container pattern was unnecessary.** Harmonia and ncro are Rust
   binaries — they don't need a Nix store inside the container. The Nix flake
   approach added a hard build-platform dependency for no runtime benefit.

## Constraints

- All container deployment must use Ansible `community.docker` modules — never
  docker compose, never systemd in production (AGENTS.md invariants)
- All ports, IPs, and domains must be infrastructure variables — never
  hardcoded (ADR-20260625001)
- `shared/` directory must be client-agnostic — no client-specific values
  (ADR-20260624001)
- Secrets must be in client vault
- macOS machines use OrbStack for containers (not Docker Desktop)

## Decision

Adopt a three-branch image sourcing decision tree with mandatory multi-arch
builds and pre-task build feasibility checks:

### Image Sourcing Decision Tree

1. **Does upstream provide a multi-arch image?** → Check GHCR, Docker Hub,
   Quay for official/verified images. If found and manifest covers all target
   archs → **Branch A: Wrap Pre-Built**.
2. **Does the service need a Nix store at runtime?** → Serves nixpkgs to Nix
   clients, needs nix CLI inside container, needs nix-store running. If yes →
   **Branch C: Nix Flake**.
3. **Otherwise** → **Branch B: Dockerfile + buildx**.

### Mandatory Multi-Arch

Never ship a single-arch `:latest` tag for the mixed-architecture fleet. Use
multi-arch manifests (`docker buildx build --platform linux/amd64,linux/arm64
--push`) or arch-specific tags. Verify with `docker manifest inspect` before
deploying.

### No Nix in Containers That Don't Need It at Runtime

If the container does not need a Nix store at runtime, do not use
`dockerTools.buildLayeredImage`. Use a multi-stage Dockerfile + `docker buildx`
instead. A Rust binary in a Debian slim image is simpler, smaller, and
buildable from any platform.

### Build Feasibility Check Before Task Creation

Before creating implementation tasks for a containerized service, verify the
build path is feasible on available build hosts. Document the build host,
target architectures, and image source in the task. If no available host can
produce the required architectures, block the task.

## Rationale

The three-branch decision tree prioritizes simplicity: pre-built images
require no build infrastructure; Dockerfiles + buildx are portable and handle
multi-arch transparently; Nix flakes are reserved for the narrow case where
the runtime genuinely needs Nix. This matches the principle "simplest tool
that produces the right artifact wins."

Multi-arch is mandatory because the fleet is mixed. Single-arch `:latest`
tags caused deployment failures when hosts pulled the wrong architecture.
Multi-arch manifests via `docker buildx --push` solve this in one command.

QEMU/binfmt emulation is avoided for heavy compilation because it is 10-24x
slower than native and known to segfault on Rust toolchains (rust-lang/rust#147026)
and the mold linker (rui314/mold#1550). Cross-compilation toolchains or native
build hosts per architecture are used instead.

Build feasibility checks before task creation prevent the painful cycle of
discovering build-platform incompatibilities mid-implementation. The
nix-cache-chain incident would have been caught at planning time if the
checks had been in place.

## Technical Approach

The decision is codified in a composable suite of artifacts:

1. **Rule** (always-on contract): `container-build-principles.md` — published
   in skills-releases, inlined into skills at build time
2. **Skill** (image build procedure): `container-image-build` — three branches
   with reference files and verification scripts
3. **Skill** (service deployment): `container-service-deploy` — compose for
   dev, Ansible for prod
4. **Skill** (infrahub overlay): `infrahub-container-deploy` — project-specific
   userns-remap, vault handoff, infra vars, role naming

Published artifacts (available after next skills-src build + publish):
- Rule: `https://github.com/levonk/skills-releases/blob/main/rules/software-dev/devops/container-build-principles.md`
- Skill: `https://github.com/levonk/skills-releases/blob/main/skills/software-dev/container-image-build/SKILL.md`
- Skill: `https://github.com/levonk/skills-releases/blob/main/skills/software-dev/container-service-deploy/SKILL.md`

Project-specific skill (travels with infrahub repo):
- `infrahub/.agents/skills/devops/infrahub-container-deploy/SKILL.md`

## Affected Components

- All containerized services across the fleet
- Build hosts (macOS, Windows WSL2, OCI cloud, isolation-vm)
- CI pipeline (GitHub Actions)
- Ansible roles for container deployment
- Task generation workflow (`tasks-from-prd.md`)

## Consequences

### Positive

- No more architecture-mismatched image deployments
- Pre-built upstream images are checked first, saving hours of unnecessary
  source builds
- Build feasibility issues are caught at planning time, not mid-implementation
- Nix flake containers are reserved for the narrow case that needs them
- Dockerfile + buildx provides a portable, multi-arch build path that works
  from any build host

### Negative

- Multi-arch builds require `--push` to a registry (cannot `--load` locally
  for multi-platform) — adds a registry dependency to the build workflow
- Cross-compilation toolchains require setup complexity for Rust/C++ builds
- Nix flake container builds remain coupled to Linux build hosts — Darwin
  users must use remote builders or cloud runners for Branch C

### Neutral

- Existing Nix flake container patterns are not banned — they are
  grandfathered for services that genuinely need Nix at runtime
- The decision tree adds a planning step before task creation — this is
  intentional shift-left, not overhead

## Alternatives Considered

- **Nix flakes for all containers**: Rejected — couples all images to Linux
  build hosts, unnecessary for binary-only services, caused the
  nix-cache-chain incident
- **QEMU emulation for all cross-arch builds**: Rejected — 10-24x slower,
  Rust segfaults, mold linker crashes
- **Single-arch images with arch-specific tags**: Partially accepted as a
  fallback when multi-arch manifests are not feasible, but multi-arch
  manifests are the default

## Rollout / Migration

1. The rule and skills are published via the skills-src pipeline
2. New containerized services follow the decision tree from the start
3. Existing services are migrated opportunistically (no forced migration)
4. The `tasks-from-prd.md` workflow is updated to include build feasibility
   checks (separate follow-up)

## Validation

- Every new containerized service has a documented image source (pre-built /
  Dockerfile / Nix flake) in its task definition
- Every deployed image passes `docker manifest inspect` verification for all
  target architectures
- No more architecture-mismatched deployment incidents

## Review Schedule

- 6 months from acceptance (2027-01-09) or after the next major fleet
  architecture change

## References

- ADR-20260708001: Nix Cache Chain — Regional Multi-Layer with Parallel Racing
  (the incident that motivated this decision)
- ADR-20260625001: Infrastructure Consolidation (infra variable naming)
- ADR-20260624001: Hybrid Sensitive Information Storage (vault strategy)
- Published rule: `container-build-principles.md` in skills-releases
- Published skill: `container-image-build` in skills-releases
- Published skill: `container-service-deploy` in skills-releases
- Project skill: `infrahub-container-deploy` in infrahub repo
- Existing workflow: `docker-standards.md` in skills-src
- Existing workflow: `nix-standards.md` in skills-src
- Rust QEMU segfault: https://github.com/rust-lang/rust/issues/147026
- mold linker QEMU crash: https://github.com/rui314/mold/issues/1550

<!-- vim: set ft=markdown: -->
