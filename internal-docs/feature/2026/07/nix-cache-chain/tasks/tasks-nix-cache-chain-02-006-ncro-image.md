---
story_id: "02-006"
story_title: "Build and push ncro container image to local registry"
story_name: "ncro-image"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 2
parallel_id: 6
branch: "feature/current/nix-cache-chain/story-02-006-ncro-image"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-002"]
parallel_safe: true
modules: ["shared/03-container/services/artifact/nix-ncro", "operational"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "nix", "container", "operational"]
due: "2026-07-22"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Build the ncro Nix flake container image (created in Story 01-002) and push it to the local Docker registry on OCI (`100.90.22.85:5000`). This is an operational task — no code changes, just build + tag + push. The image must be available before the nix-ncro Ansible role (Story 02-003) can deploy it, and before Story 04-001 can run.

## Current State

- **Relevant files and their roles:**
  - `shared/active/03-container/services/artifact/nix-ncro/flake.nix` — flake created in Story 01-002, builds `ncro:latest` via `.#docker-prod`
  - `shared/active/03-container/services/artifact/nix-ncro/Makefile` — has `make build` target

- **Registry details:**
  - URL: `100.90.22.85:5000`
  - Target image name: `100.90.22.85:5000/localnet-nix-ncro:latest`

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Build image | `cd shared/active/03-container/services/artifact/nix-ncro && nix build .#docker-prod` | exit 0, `result` symlink |
  | Load image | `docker load < result` | `Loaded image: ncro:latest` |
  | Tag image | `docker tag ncro:latest 100.90.22.85:5000/localnet-nix-ncro:latest` | exit 0 |
  | Push image | `docker push 100.90.22.85:5000/localnet-nix-ncro:latest` | exit 0 |

## Scope

**In scope:**
- Build the ncro Docker image using the Nix flake (from Story 01-002)
- Load, tag, and push to the local registry

**Out of scope:**
- Creating the flake (Story 01-002)
- Ansible role (Story 02-003)
- Deployment (Story 04-001)

## Sub-Tasks

- [ ] Task 1 — Build the ncro image
  `cd shared/active/03-container/services/artifact/nix-ncro && nix build .#docker-prod`
  **Verify**: `ls -la shared/active/03-container/services/artifact/nix-ncro/result` → symlink exists

- [ ] Task 2 — Load the image into Docker
  `docker load < shared/active/03-container/services/artifact/nix-ncro/result`
  **Verify**: `docker images ncro` → shows `ncro latest`

- [ ] Task 3 — Tag for local registry
  `docker tag ncro:latest 100.90.22.85:5000/localnet-nix-ncro:latest`
  **Verify**: `docker images | grep localnet-nix-ncro` → shows the tagged image

- [ ] Task 4 — Push to local registry
  `docker push 100.90.22.85:5000/localnet-nix-ncro:latest`
  **Verify**: `curl -s http://100.90.22.85:5000/v2/localnet-nix-ncro/tags/list` → `{"name":"localnet-nix-ncro","tags":["latest"]}`

## Relevant Files

- `shared/active/03-container/services/artifact/nix-ncro/flake.nix` — flake from Story 01-002 (READ ONLY)

## Acceptance Criteria

- [ ] `nix build .#docker-prod` succeeds
- [ ] Image pushed to local registry (verified via API)
- [ ] No files modified

## Test Plan

- Registry API check: `curl -s http://100.90.22.85:5000/v2/localnet-nix-ncro/tags/list`

## Observability

- No metrics changes — operational build task

## Compliance

- ncro is EUPL 1.2 licensed — no specific compliance concerns for self-hosting

## Risks & Mitigations

- Risk: Nix build fails (ncro flake input issues) — Mitigation: Debug flake.nix from Story 01-002; check ncro repo for build requirements
- Risk: Local registry not running — Mitigation: Run `deploy-local-registry.yml` first
- Risk: ncro binary crashes on startup — Mitigation: Test `docker run --rm ncro:latest --help` before pushing

## Dependencies & Sequencing

- Depends on: 01-002 (ncro flake must exist)
- Unblocks: 04-001 (deployment needs the image in the registry)

## Definition of Done

- [ ] Image exists in local registry
- [ ] No files modified

## STOP Conditions

Stop and report if:
- `nix build .#docker-prod` fails (flake broken — go back to Story 01-002)
- Local registry not reachable
- ncro binary crashes on startup

## Maintenance Notes

- Rebuild when ncro releases new versions
- Pin to a specific ncro commit for reproducibility (update flake input)

## Commit Conventions

- No code changes — no commit needed

## Changelog

- 2026-07-08: initialized story file
