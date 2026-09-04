---
title: "Nix Cache Chain CNO Dual-Deployment"
slug: nix-cache-chain-cno-dual-deployment
date:
  created: 2026-08-09
  last-updated: 2026-08-09
status: done
tech-context: |
  ## Tech Context (Binding Constraint)
  This project uses the following tools. Use them, not alternatives.
  - Package manager: N/A (Ansible infrastructure, no application code)
  - Ad-hoc runner: devbox run -- <command>
  - Build system: Just (Justfile recipes)
  - Test runner: ansible-lint, ansible-syntax-check
  - Linter: ansible-lint, yamllint
  - Container runtime: Docker (via community.docker modules on Linux; via ssh:// CLI on Windows)
  - Image build: Nix flakes (harmonia, ncro) — build on OCI natively for ARM64
  - CI/CD: GitHub Actions
  System tools run via: devbox run -- <command>
  Never use: npm, npx, yarn, jest, biome
---

# PRD: Nix Cache Chain CNO Dual-Deployment

## Summary

Extend the existing Nix cache chain (Harmonia + ncps + ncro) from the `nl`
network (dtop202311, Windows Docker Desktop, X86) to the `cno` network
(oci-cloud-server, Linux ARM64) at `cache.cno.levonk.com`.

This mirrors the `verdaccio-dual-deployment` pattern: refactor the three
existing Windows-only roles to support both Linux (community.docker) and
Windows (ssh CLI) deployment paths, add cno infrastructure variables, Traefik
routing, and build ARM64 container images for the locally-built services.

## Background

The Nix cache chain was deployed to `nl` (dtop202311) per
ADR-202607080001. The three roles (`nix-harmonia`, `nix-ncps`, `nix-ncro`)
only have Windows deployment paths (ssh-tunneled Docker CLI). The OCI cloud
server runs Nix natively (via `nix-installation` role in
`cloud-server-bootstrap.yml`) and has `/nix/store` on the host filesystem.

The `verdaccio-dual-deployment` feature established the dual-deployment
pattern: a single role with `deploy-linux.yml` (community.docker) and
`deploy-windows.yml` (ssh CLI) task files, dispatched by inventory group.

## Requirements

### Functional

1. **Harmonia on OCI (cno)**: Container serving `/nix/store` over HTTP on
   `127.0.0.1` only. Bind mounts `/nix/store` and `/nix/var/nix/db` from the
   host (not a Docker volume — OCI has Nix natively on the host).
2. **ncps on OCI (cno)**: NAR caching proxy at `cache.cno.levonk.com` via
   Traefik. Uses upstream multi-arch image `ghcr.io/kalbasit/ncps:v0.9.4`.
   Joins `traefik-network`.
3. **ncro on OCI (cno)**: Parallel racing proxy behind ncps. Locally-built
   ARM64 image from Nix flake. Joins `traefik-network`.
4. **Traefik routing**: `cache.cno.levonk.com` → ncps container on OCI (same
   machine, container network).
5. **DNS**: `cache.cno.levonk.com` CNAME → `oci.tale-grouper.ts.net`.
6. **ARM64 images**: Build harmonia and ncro images for `aarch64-linux` on
   the OCI server natively (Nix is already installed there).
7. **Dual-deployment roles**: All three roles refactored to support both
   Linux (community.docker) and Windows (ssh CLI) paths, dispatched by
   inventory group.

### Non-Functional

1. All ports/IPs/domains as `infra_*` variables (no hardcoding)
2. `community.docker.docker_container` on Linux (cno)
3. `ansible.builtin.shell` + `DOCKER_HOST: ssh://` + `delegate_to: localhost`
   on Windows (nl) — unchanged from existing
4. All containers run with `no-new-privileges:true`
5. Healthchecks with string unit suffixes (`"30s"`, not `30`)
6. Nix flakes updated to support both `x86_64-linux` and `aarch64-linux`

### Architecture

```
cno (OCI cloud server, ARM64, Linux):
  Harmonia @ 127.0.0.1:4523  (bind mounts /nix/store from host)
  ncps @ 0.0.0.0:4524 → cache.cno.levonk.com (via Traefik)
    upstream: ncro @ 127.0.0.1:4525
  ncro @ 127.0.0.1:4525 → races:
    - http://localnet-nix-harmonia:5000 (local Harmonia)
    - https://cache.nixos.org
    - https://cache.garnix.io
    - https://nix-community.cachix.org

nl (dtop202311, Windows Docker Desktop, X86) — unchanged:
  Harmonia @ 127.0.0.1:4523  (nix-sidecar volume)
  ncps @ 0.0.0.0:4524 → cache.nl.levonk.com (via Traefik Windows)
  ncro @ 127.0.0.1:4525
```

## Scope

### In Scope

- Shared infrastructure schemas (cno domain, hostnames, storage for cno)
- Client infrastructure overrides (cno domain, DNS CNAME)
- Nix flake updates for `aarch64-linux` support (harmonia + ncro)
- Role refactoring: `nix-harmonia`, `nix-ncps`, `nix-ncro` — add
  `deploy-linux.yml` to each, dispatch by inventory group
- Traefik dynamic config template for `cache.cno.levonk.com`
- Playbook update: `deploy-nix-cache-and-garnix.yml` to target both
  `cloud_servers` and `windows_docker_hosts`
- Service catalog: cno entries in `services.yml`, regenerate both catalogs
- ARM64 image build on OCI

### Out of Scope

- Attic deployment (separate feature, PRD FR-4)
- nix.conf client configuration on OCI (separate story)
- Harmonia on Macs (already deployed or separate feature)
- Garnix CI on OCI (stays nl-only)

## Implementation Guide Reference

Task stories should reference `.agents/workflows/infrahub-add-new-service.md` for:
- Phase 1: Shared Infrastructure Schemas
- Phase 2: Client Infrastructure Values
- Phase 5: Create the Ansible Role (dual-deployment pattern)
- Phase 6: Traefik Routing

Reference feature: `internal-docs/feature/2026/08/verdaccio-dual-deployment/`
—the proven dual-deployment template.

## Acceptance Criteria

1. `cache.cno.levonk.com` resolves and ncps responds with healthy status
2. Harmonia responds on `127.0.0.1:4523` on OCI
3. ncro `/health` returns JSON with upstreams on OCI
4. All three roles deploy successfully on both nl and cno
5. `ansible-lint` and `ansible-syntax-check` pass
6. No hardcoded IPs or ports in any new/modified file
7. Service catalog regenerated with cno entries
8. Nix flakes build for both `x86_64-linux` and `aarch64-linux`
