---
story_id: "01-004"
story_title: "Build and push Harmonia container image to local registry"
story_name: "harmonia-image"
prd_name: "nix-cache-chain"
prd_file: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
phase: 1
parallel_id: 4
branch: "feature/current/nix-cache-chain/story-01-004-harmonia-image"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared/03-container/services/artifact/nix-harmonia", "operational"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "nix", "container", "operational"]
due: "2026-07-15"
created_at: "2026-07-08"
updated_at: "2026-07-08"
---

## Summary

Build the existing Harmonia Nix flake container image and push it to the local Docker registry on OCI (`100.90.22.85:5000`). The flake already exists at `shared/active/03-container/services/artifact/nix-harmonia/`. This is an operational task — no code changes, just build + tag + push. The image must be available in the registry before the nix-harmonia Ansible role (Story 02-001) can deploy it.

## Current State

- **Relevant files and their roles:**
  - `shared/active/03-container/services/artifact/nix-harmonia/flake.nix` — existing flake, builds `harmonia:latest` via `.#docker-prod`
  - `shared/active/03-container/services/artifact/nix-harmonia/Makefile` — has `make build` target (`nix build .#docker-prod && docker load < result`)
  - `shared/active/02-config/ansible/playbooks/deploy-local-registry.yml` — deploys the local registry on cloud_servers at port 5000

- **Registry details:**
  - URL: `100.90.22.85:5000` (OCI cloud server Tailscale IP, port 5000)
  - HTTP only — Tailscale encrypts transport
  - Image naming pattern: `{{ local_registry | default('100.90.22.85:5000') }}/localnet-<service>:latest`
  - Target image name: `100.90.22.85:5000/localnet-nix-harmonia:latest`

- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Build image | `cd shared/active/03-container/services/artifact/nix-harmonia && nix build .#docker-prod` | exit 0, `result` symlink |
  | Load image | `docker load < result` | `Loaded image: harmonia:latest` |
  | Tag image | `docker tag harmonia:latest 100.90.22.85:5000/localnet-nix-harmonia:latest` | exit 0 |
  | Push image | `docker push 100.90.22.85:5000/localnet-nix-harmonia:latest` | exit 0 |

## Scope

**In scope:**
- Build the Harmonia Docker image using the existing Nix flake
- Load it into local Docker
- Tag it for the local registry
- Push it to the local registry on OCI

**Out of scope:**
- Modifying the flake.nix (that's the existing definition, no changes needed)
- Ansible role creation (Story 02-001)
- Deploying Harmonia containers (Story 04-001)

## Sub-Tasks

- [ ] Task 1 — Build the Harmonia image
  `cd shared/active/03-container/services/artifact/nix-harmonia && nix build .#docker-prod`
  **Verify**: `ls -la shared/active/03-container/services/artifact/nix-harmonia/result` → symlink exists

- [ ] Task 2 — Load the image into Docker
  `docker load < shared/active/03-container/services/artifact/nix-harmonia/result`
  **Verify**: `docker images harmonia` → shows `harmonia latest` with a recent timestamp

- [ ] Task 3 — Tag for local registry
  `docker tag harmonia:latest 100.90.22.85:5000/localnet-nix-harmonia:latest`
  **Verify**: `docker images | grep localnet-nix-harmonia` → shows the tagged image

- [ ] Task 4 — Push to local registry
  `docker push 100.90.22.85:5000/localnet-nix-harmonia:latest`
  **Verify**: `curl -s http://100.90.22.85:5000/v2/localnet-nix-harmonia/tags/list` → `{"name":"localnet-nix-harmonia","tags":["latest"]}`

## Relevant Files

- `shared/active/03-container/services/artifact/nix-harmonia/flake.nix` — existing flake (READ ONLY, no changes)
- `shared/active/03-container/services/artifact/nix-harmonia/Makefile` — existing Makefile (can use `make build` as alternative)

## Acceptance Criteria

- [ ] `nix build .#docker-prod` succeeds
- [ ] Image loaded into local Docker
- [ ] Image tagged as `100.90.22.85:5000/localnet-nix-harmonia:latest`
- [ ] Image pushed to local registry (verified via registry API)
- [ ] No files modified (operational task only)

## Test Plan

- Registry API check: `curl -s http://100.90.22.85:5000/v2/localnet-nix-harmonia/tags/list` returns the image
- Docker pull test: `docker pull 100.90.22.85:5000/localnet-nix-harmonia:latest` succeeds from a different machine (optional, if Tailscale is connected)

## Observability

- No metrics changes — operational build task

## Compliance

- No regulatory concerns — building and pushing a public open-source image

## Risks & Mitigations

- Risk: Nix build fails on macOS (flake targets `x86_64-linux`) — Mitigation: Build on a Linux machine or use `nix build .#docker-prod --system x86_64-linux` with binfmt/qemu emulation, or build on the OCI cloud server directly
- Risk: Local registry not running — Mitigation: Run `deploy-local-registry.yml` playbook first: `devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/deploy-local-registry.yml --vault-password-file ~/.ansible/vault_password`
- Risk: Docker push fails (registry unreachable) — Mitigation: Verify Tailscale connectivity to OCI, check registry container is running

## Dependencies & Sequencing

- Depends on: None (flake exists, registry exists)
- Unblocks: Story 04-001 (deployment needs the image in the registry)

## Definition of Done

- [ ] Image exists in local registry (verified via API)
- [ ] No files modified in the repo

## STOP Conditions

Stop and report if:
- `nix build .#docker-prod` fails (flake broken)
- Local registry is not running and cannot be started
- Docker push fails after verifying connectivity

## Maintenance Notes

- Rebuild and push when Harmonia releases new versions
- The flake pins to `github:nix-community/harmonia` (unstable) — consider pinning to a specific commit for reproducibility

## Commit Conventions

- No code changes — no commit needed. If Makefile or flake needs fixing: `fix(nix-harmonia): ...`

## Changelog

- 2026-07-08: initialized story file
