---
story_id: "01-005"
story_title: "Build and push Attic container image to local registry"
story_name: "attic-image"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 1
parallel_id: 5
branch: "feature/current/nix-cache-chain/story-01-005-attic-image"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared/03-container/services/artifact/nix-attic", "operational"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "nix", "container", "operational"]
due: "2026-07-15"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Build the existing Attic Nix flake container image and push it to the local Docker registry on OCI (`100.90.22.85:5000`). The flake already exists at `shared/active/03-container/services/artifact/nix-attic/`. This is an operational task — no code changes, just build + tag + push. The image must be available before the nix-attic Ansible role (Story 02-004) can deploy it.

## Current State

- **Relevant files and their roles:**
  - `shared/active/03-container/services/artifact/nix-attic/flake.nix` — existing flake, builds `attic-server:latest` via `.#docker-prod`. Uses `attic.packages.${system}.attic-server`. Exposes port 8080. Mounts `/data`. Sets `ATTIC_SERVER_DATABASE_URL=sqlite:///data/server.db`.
  - `shared/active/03-container/services/artifact/nix-attic/Makefile` — has `make build` target

- **Registry details:**
  - URL: `100.90.22.85:5000`
  - Target image name: `100.90.22.85:5000/localnet-nix-attic:latest`

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Build image | `cd shared/active/03-container/services/artifact/nix-attic && nix build .#docker-prod` | exit 0, `result` symlink |
  | Load image | `docker load < result` | `Loaded image: attic-server:latest` |
  | Tag image | `docker tag attic-server:latest 100.90.22.85:5000/localnet-nix-attic:latest` | exit 0 |
  | Push image | `docker push 100.90.22.85:5000/localnet-nix-attic:latest` | exit 0 |

## Scope

**In scope:**
- Build the Attic Docker image using the existing Nix flake
- Load, tag, and push to the local registry

**Out of scope:**
- Modifying the flake.nix
- Ansible role creation (Story 02-004)
- Deploying Attic container (Story 04-001)

## Sub-Tasks

- [ ] Task 1 — Build the Attic image
  `cd shared/active/03-container/services/artifact/nix-attic && nix build .#docker-prod`
  **Verify**: `ls -la shared/active/03-container/services/artifact/nix-attic/result` → symlink exists

- [ ] Task 2 — Load the image into Docker
  `docker load < shared/active/03-container/services/artifact/nix-attic/result`
  **Verify**: `docker images attic-server` → shows `attic-server latest`

- [ ] Task 3 — Tag for local registry
  `docker tag attic-server:latest 100.90.22.85:5000/localnet-nix-attic:latest`
  **Verify**: `docker images | grep localnet-nix-attic` → shows the tagged image

- [ ] Task 4 — Push to local registry
  `docker push 100.90.22.85:5000/localnet-nix-attic:latest`
  **Verify**: `curl -s http://100.90.22.85:5000/v2/localnet-nix-attic/tags/list` → `{"name":"localnet-nix-attic","tags":["latest"]}`

## Relevant Files

- `shared/active/03-container/services/artifact/nix-attic/flake.nix` — existing flake (READ ONLY)

## Acceptance Criteria

- [ ] `nix build .#docker-prod` succeeds
- [ ] Image pushed to local registry (verified via API)
- [ ] No files modified

## Test Plan

- Registry API check: `curl -s http://100.90.22.85:5000/v2/localnet-nix-attic/tags/list`

## Observability

- No metrics changes — operational build task

## Compliance

- Attic is GPL-3.0 — no specific compliance concerns for self-hosting

## Risks & Mitigations

- Risk: Nix build fails on macOS (flake targets `x86_64-linux`) — Mitigation: Build on Linux or use emulation
- Risk: Local registry not running — Mitigation: Run `deploy-local-registry.yml` first

## Dependencies & Sequencing

- Depends on: None
- Unblocks: Story 04-001 (deployment needs the image)

## Definition of Done

- [ ] Image exists in local registry
- [ ] No files modified

## STOP Conditions

Stop and report if:
- `nix build .#docker-prod` fails
- Local registry not reachable

## Maintenance Notes

- Rebuild when Attic releases new versions
- The flake uses `github:zhaofengli/attic` — consider pinning to a specific commit

## Commit Conventions

- No code changes — no commit needed

## Changelog

- 2026-07-08: initialized story file
