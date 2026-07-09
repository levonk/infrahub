---
story_id: "01-002"
story_title: "Create ncro Nix flake container definition"
story_name: "ncro-flake"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 1
parallel_id: 2
branch: "feature/current/nix-cache-chain/story-01-002-ncro-flake"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared/03-container/services/artifact/nix-ncro"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "nix", "container"]
due: "2026-07-15"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Create a Nix flake container definition for ncro (parallel racing Nix cache proxy) under `shared/active/03-container/services/artifact/nix-ncro/`. ncro has no official Docker image and is not in nixpkgs, so it must be built from source via a Nix flake. This follows the exact pattern of the existing nix-harmonia, nix-ncps, and nix-attic flake definitions. ncro is a Rust project from https://github.com/feel-co/ncro.

## Current State

- **Relevant files and their roles:**
  - `shared/active/03-container/services/artifact/nix-harmonia/flake.nix` — existing flake pattern to follow. Uses `pkgs.dockerTools.buildLayeredImage` with `docker-prod` and `docker-debug` output attributes. Exposes port 5000, mounts `/data` and `/nix/store`.
  - `shared/active/03-container/services/artifact/nix-ncps/flake.nix` — another flake pattern. Exposes port 8080, mounts `/data`. Has `config.toml` alongside.
  - `shared/active/03-container/services/artifact/nix-attic/flake.nix` — Attic flake. Exposes port 8080, mounts `/data`. Uses `attic.packages.${system}.attic-server`.
  - `shared/active/03-container/services/artifact/README.md` — overview of artifact services (lists nix-harmonia, nix-ncps, nix-attic, nix-snapshotter, nexus, verdaccio)

- **Existing code excerpts (nix-harmonia flake.nix — the pattern to replicate):**
  ```nix
  {
    description = "Harmonia - Nix Binary Cache";
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      harmonia.url = "github:nix-community/harmonia";
      harmonia.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = { self, nixpkgs, harmonia }:
      let
        system = "x86_64-linux";
        pkgs = import nixpkgs { inherit system; config = { ... }; };
        harmoniaPkg = harmonia.packages.${system}.default;
        commonConfig = {
          Entrypoint = [ "${harmoniaPkg}/bin/harmonia" ];
          ExposedPorts = { "5000/tcp" = {}; };
          WorkingDir = "/data";
          Volumes = { "/data" = {}; "/nix/store" = {}; };
          Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
        };
      in {
        packages.${system} = {
          default = harmoniaPkg;
          docker-prod = pkgs.dockerTools.buildLayeredImage {
            name = "harmonia"; tag = "latest"; created = "now";
            contents = [ harmoniaPkg pkgs.bash pkgs.coreutils pkgs.nix pkgs.iana-etc pkgs.cacert ];
            config = commonConfig;
          };
          docker-debug = pkgs.dockerTools.buildLayeredImage { ... };
        };
      };
  }
  ```

- **ncro specifics (from ADR and research):**
  - Source: https://github.com/feel-co/ncro
  - Language: Rust
  - Config: TOML format
  - Port: 8081 (per PRD FR-3)
  - Binds to 127.0.0.1 (only ncps talks to it)
  - Races all upstreams in parallel (Harmonia instances, Attic, Cachix, cache.nixos.org)
  - No NAR storage (streams only) — but needs a small SQLite DB for EMA latency tracking
  - Health endpoint: `/health` (returns JSON with upstream status)

- **Repository conventions:**
  - All flake definitions follow the same structure: `docker-prod` + `docker-debug` outputs
  - All include `pkgs.cacert` and set `SSL_CERT_FILE` env
  - All include `pkgs.bash` and `pkgs.coreutils` in prod
  - Debug variant adds network tools (curl, wget, iproute2, jq, etc.)
  - Makefile pattern: `build`, `build-debug`, `up`, `down`, `logs`, `health-check`, `clean` targets

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Build prod image | `cd shared/active/03-container/services/artifact/nix-ncro && nix build .#docker-prod` | exit 0, `result` symlink created |
  | Load into Docker | `docker load < result` | Image loaded as `ncro:latest` |
  | Build debug image | `nix build .#docker-debug` | exit 0 |

## Scope

**In scope:**
- Create `shared/active/03-container/services/artifact/nix-ncro/flake.nix` — Nix flake that builds ncro from the `github:feel-co/ncro` flake input, produces `docker-prod` and `docker-debug` images
- Create `shared/active/03-container/services/artifact/nix-ncro/README.md` — documentation following the pattern of nix-harmonia/README.md
- Create `shared/active/03-container/services/artifact/nix-ncro/Makefile` — build targets following the existing Makefile pattern
- Create `shared/active/03-container/services/artifact/nix-ncro/config.toml` — example/default ncro config (TOML format, listing upstreams, port 8081, 127.0.0.1 bind)

**Out of scope:**
- Building and pushing the image to the local registry (Story 02-006)
- Ansible role for deploying ncro (Story 02-003)
- ncro config templating via Ansible (Story 02-003)

## Sub-Tasks

- [x] Task 1 — Create `shared/active/03-container/services/artifact/nix-ncro/flake.nix`
  Follow the nix-harmonia flake pattern. Use `ncro.url = "github:feel-co/ncro"` as the flake input. Set `system = "x86_64-linux"`. Expose port 8081. Mount `/data` (for SQLite DB). Set `Entrypoint` to `"${ncroPkg}/bin/ncro"`. Include `pkgs.cacert`, `pkgs.bash`, `pkgs.coreutils` in prod contents. Add `SSL_CERT_FILE` env. Create both `docker-prod` and `docker-debug` outputs.
  **Verify**: `cd shared/active/03-container/services/artifact/nix-ncro && nix flake check` → exit 0 (or warnings only, no errors)

- [x] Task 2 — Create `shared/active/03-container/services/artifact/nix-ncro/config.toml`
  Example ncro config with: listen address `127.0.0.1`, port `8081`, upstream list (all 5 Harmonia instances, Attic, cache.nixos.org), logging level `info`, format `json`. This is a reference config — the Ansible role will template the real config with infrastructure variables.
  **Verify**: `python3 -c "import tomllib; tomllib.loads(open('shared/active/03-container/services/artifact/nix-ncro/config.toml').read())"` → exit 0 (valid TOML, Python 3.11+)

- [x] Task 3 — Create `shared/active/03-container/services/artifact/nix-ncro/Makefile`
  Follow the nix-harmonia Makefile pattern: `build` (nix build .#docker-prod && docker load), `build-debug`, `up`, `down`, `logs`, `health-check`, `clean`, `help` targets.
  **Verify**: `make -C shared/active/03-container/services/artifact/nix-ncro help` → prints available commands

- [x] Task 4 — Create `shared/active/03-container/services/artifact/nix-ncro/README.md`
  Document: purpose (parallel racing Nix cache proxy), build instructions, usage, config format, health endpoint. Follow the nix-harmonia README structure.
  **Verify**: File exists and contains "ncro" and "build" and "config" keywords

- [ ] Task 5 — Build the prod image to verify the flake works
  **Verify**: `cd shared/active/03-container/services/artifact/nix-ncro && nix build .#docker-prod` → exit 0, `result` symlink exists
  **Note**: Build deferred to Story 02-006 (Linux). Fails on macOS with "does not provide attribute 'packages.x86_64-darwin.docker-prod'" — expected since flake targets x86_64-linux only.

- [ ] Task 6 — Load and verify the image
  **Verify**: `docker load < shared/active/03-container/services/artifact/nix-ncro/result` → `Loaded image: ncro:latest`
  **Note**: Deferred to Story 02-006 (requires Linux build first).

## Relevant Files

- `shared/active/03-container/services/artifact/nix-ncro/flake.nix` — new flake definition (CREATE)
- `shared/active/03-container/services/artifact/nix-ncro/config.toml` — example config (CREATE)
- `shared/active/03-container/services/artifact/nix-ncro/Makefile` — build targets (CREATE)
- `shared/active/03-container/services/artifact/nix-ncro/README.md` — documentation (CREATE)

## Acceptance Criteria

- [ ] `nix build .#docker-prod` succeeds in the nix-ncro directory
  *(Deferred to Story 02-006 — fails on macOS, targets x86_64-linux)*
- [ ] `docker load < result` produces a `ncro:latest` image
  *(Deferred to Story 02-006)*
- [x] flake.nix follows the same structure as nix-harmonia/nix-ncps/nix-attic
- [x] config.toml is valid TOML with port 8081 and 127.0.0.1 bind
- [x] README.md documents build and usage

## Test Plan

- Nix build: `nix build .#docker-prod` — must exit 0
- Docker load: `docker load < result` — must succeed
- TOML validation: `python3 -c "import tomllib; tomllib.loads(open('config.toml').read())"` — must exit 0
- Flake check: `nix flake check` — no errors

## Observability

- ncro exposes Prometheus metrics (7 metrics) and `/health` JSON endpoint — document in README

## Compliance

- ncro is EUPL 1.2 licensed — note in README

## Risks & Mitigations

- Risk: ncro flake input may not provide a pre-built package for x86_64-linux — Mitigation: Check the ncro repo's flake.nix for available outputs; if no `packages.x86_64-linux.default`, build from source using `ncroSrc` with `pkgs.rustPlatform.buildRustPackage`
- Risk: ncro may require specific Rust toolchain or dependencies — Mitigation: Use `naersk` or `crane` for Rust builds if the upstream flake doesn't work directly
- Risk: ncro may not have a flake.nix at all — Mitigation: Use `ncro.url = "github:feel-co/ncro"` and check; if no flake, vendor the source and build with `buildRustPackage`

## Dependencies & Sequencing

- Depends on: None (can build ncro independently)
- Unblocks: Story 02-003 (ncro Ansible role needs the image), Story 02-006 (build + push ncro image)

## Definition of Done

- [ ] `nix build .#docker-prod` succeeds
  *(Deferred to Story 02-006 — Linux build required)*
- [ ] `docker load < result` succeeds
  *(Deferred to Story 02-006)*
- [x] All files created (flake.nix, config.toml, Makefile, README.md)
- [x] No files outside `shared/active/03-container/services/artifact/nix-ncro/` are modified
  *(Exception: artifact README.md updated to list nix-ncro, and this task file updated)*

## STOP Conditions

Stop and report if:
- ncro cannot be built via Nix (no flake, no package, buildRustPackage fails)
- The ncro repo doesn't exist or has been removed
- The built image doesn't start or crashes immediately

## Maintenance Notes

- ncro is a new project (May 2026) — pin to a specific commit for reproducibility
- Update the flake input when ncro releases new versions
- The config.toml is a reference — actual config is templated by Ansible (Story 02-003)

## Commit Conventions

- `feat(nix-ncro): add Nix flake container definition for ncro parallel racing proxy`

## Changelog

- 2026-07-08: initialized story file
- 2026-07-08: completed Tasks 1-4 (flake.nix, config.toml, Makefile, README.md). nix flake check passes. TOML valid. make help works. Build deferred to Story 02-006 (x86_64-linux target, fails on macOS).
