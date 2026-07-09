---
title: "Nix Cache Chain — Task Index"
prd: "internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md"
adr: "shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md"
feature_slug: "nix-cache-chain"
created_at: "2026-07-08"
updated_at: "2026-07-08"
status: "todo"
total_stories: 14
phases: 4
---

# Nix Cache Chain — Task Index

## Overview

This index tracks all implementation stories for the Nix Cache Chain feature, which replaces the outdated sequential "waterfall" cache strategy with a regional multi-layer parallel racing architecture.

**PRD:** [`feat-202607081745-nix-cache-chain.md`](../feat-202607081745-nix-cache-chain.md)
**ADR:** [`adr-20260708001-nix-cache-chain-regional-parallel-racing.md`](../../../../../../shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md)

## Architecture Summary

```
Every Nix machine nix.conf:
  priority 10: http://127.0.0.1:<port>         (local Harmonia)
  priority 20: http://<regional-ncps>:<port>   (regional ncps)

REGION 1 (LAN): dtop202311 hosts ncps + ncro
  ncps (front, caches NARs) → ncro (races upstreams in parallel)
  ncro upstreams: all Harmonia everywhere + Attic + cache.nixos.org

REGION 2 (Cloud): oci-cloud-server hosts ncps + ncro + Attic
  ncps (front, caches NARs) → ncro (races upstreams in parallel)
  ncro upstreams: all Harmonia everywhere + Attic (local) + cache.nixos.org
```

## Target Machines

| Machine | OS | Harmonia | ncps | ncro | Attic | nix.conf |
|---------|-----|----------|------|------|-------|----------|
| lzkmbp2016 | macOS | YES | — | — | — | YES (LAN) |
| lzkmbp2018 | macOS | YES | — | — | — | YES (LAN) |
| dtop202311 | Windows | YES | YES | YES | — | YES (LAN) |
| oci-cloud-server | Linux | YES | YES | YES | YES | YES (Cloud) |
| isolation-vm | Linux | YES | — | — | — | YES (Cloud) |
| kckinai | Linux | — | — | — | — | — (no Nix) |

## Dependency Graph

```
Phase 1 (parallel):
  01-001 Infra Variables ─┬─→ 02-001 Harmonia Role ──┐
  01-002 ncro Flake ──────┤   02-002 ncps Role ───────┤
  01-003 Vault Secrets ───┼─→ 02-003 ncro Role ───────┼─→ 03-001 Playbook ─┬─→ 04-001 Deploy Services
  01-004 Harmonia Image ──┤   02-004 Attic Role ──────┤                   │
  01-005 Attic Image ─────┘   02-005 Client Config ───┘                   └─→ 04-002 Deploy Client Config
                              02-006 ncro Image ─────────────────────────────→ 04-001 (image dependency)
```

## Story Index

### Phase 1 — Foundation (no dependencies, all parallel-safe)

| ID | Story | Branch | Risk | Status | File |
|----|-------|--------|------|--------|------|
| 01-001 | Infrastructure variables (ports, storage, Tailscale IPs) | `story-01-001-infra-variables` | low | todo | [tasks-nix-cache-chain-01-001-infra-variables.md](tasks-nix-cache-chain-01-001-infra-variables.md) |
| 01-002 | ncro Nix flake container definition | `story-01-002-ncro-flake` | high | todo | [tasks-nix-cache-chain-01-002-ncro-flake.md](tasks-nix-cache-chain-01-002-ncro-flake.md) |
| 01-003 | Vault secrets handoff (user task) | `story-01-003-vault-secrets` | medium | todo | [tasks-nix-cache-chain-01-003-vault-secrets.md](tasks-nix-cache-chain-01-003-vault-secrets.md) |
| 01-004 | Build + push Harmonia image to local registry | `story-01-004-harmonia-image` | low | todo | [tasks-nix-cache-chain-01-004-harmonia-image.md](tasks-nix-cache-chain-01-004-harmonia-image.md) |
| 01-005 | Build + push Attic image to local registry | `story-01-005-attic-image` | low | todo | [tasks-nix-cache-chain-01-005-attic-image.md](tasks-nix-cache-chain-01-005-attic-image.md) |

### Phase 2 — Ansible Roles + ncro Image (depend on Phase 1, parallel-safe within phase)

| ID | Story | Branch | Risk | Deps | Status | File |
|----|-------|--------|------|------|--------|------|
| 02-001 | nix-harmonia Ansible role | `story-02-001-harmonia-role` | medium | 01-001, 01-003 | todo | [tasks-nix-cache-chain-02-001-harmonia-role.md](tasks-nix-cache-chain-02-001-harmonia-role.md) |
| 02-002 | nix-ncps Ansible role | `story-02-002-ncps-role` | medium | 01-001 | todo | [tasks-nix-cache-chain-02-002-ncps-role.md](tasks-nix-cache-chain-02-002-ncps-role.md) |
| 02-003 | nix-ncro Ansible role | `story-02-003-ncro-role` | high | 01-001, 01-003 | todo | [tasks-nix-cache-chain-02-003-ncro-role.md](tasks-nix-cache-chain-02-003-ncro-role.md) |
| 02-004 | nix-attic Ansible role | `story-02-004-attic-role` | medium | 01-001, 01-003 | todo | [tasks-nix-cache-chain-02-004-attic-role.md](tasks-nix-cache-chain-02-004-attic-role.md) |
| 02-005 | nix-client-config Ansible role (nix.conf) | `story-02-005-client-config-role` | medium | 01-001 | todo | [tasks-nix-cache-chain-02-005-client-config-role.md](tasks-nix-cache-chain-02-005-client-config-role.md) |
| 02-006 | Build + push ncro image to local registry | `story-02-006-ncro-image` | high | 01-002 | todo | [tasks-nix-cache-chain-02-006-ncro-image.md](tasks-nix-cache-chain-02-006-ncro-image.md) |

### Phase 3 — Playbook + Inventory (depends on Phase 2)

| ID | Story | Branch | Risk | Deps | Status | File |
|----|-------|--------|------|------|--------|------|
| 03-001 | nix-cache.yml playbook + inventory groups | `story-03-001-playbook-inventory` | medium | 02-001, 02-002, 02-003, 02-004, 02-005 | todo | [tasks-nix-cache-chain-03-001-playbook-inventory.md](tasks-nix-cache-chain-03-001-playbook-inventory.md) |

### Phase 4 — Deploy + End-to-End Verification (depends on Phase 3)

| ID | Story | Branch | Risk | Deps | Status | File |
|----|-------|--------|------|------|--------|------|
| 04-001 | Deploy cache services + verify health endpoints | `story-04-001-deploy-cache-services` | high | 03-001, 01-003, 01-004, 01-005, 02-006 | todo | [tasks-nix-cache-chain-04-001-deploy-cache-services.md](tasks-nix-cache-chain-04-001-deploy-cache-services.md) |
| 04-002 | Deploy nix.conf client config + verify substitution | `story-04-002-deploy-client-config` | medium | 03-001, 04-001 | todo | [tasks-nix-cache-chain-04-002-deploy-client-config.md](tasks-nix-cache-chain-04-002-deploy-client-config.md) |

## Execution Order

### Wave 1 (parallel — Phase 1)
- 01-001, 01-002, 01-003, 01-004, 01-005

### Wave 2 (parallel — Phase 2, after Wave 1)
- 02-001, 02-002, 02-003, 02-004, 02-005, 02-006

### Wave 3 (sequential — Phase 3, after Wave 2)
- 03-001

### Wave 4 (sequential — Phase 4, after Wave 3)
- 04-001, then 04-002

## Key Conventions

- **Branch prefix:** `feature/current/nix-cache-chain/story-<ID>-<name>`
- **Roles:** `shared/active/02-config/ansible/roles/nix-{service}/`
- **Playbook:** `shared/active/02-config/ansible/playbooks/nix-cache.yml`
- **Container images:** `100.90.22.85:5000/localnet-nix-{service}:latest`
- **Vault secrets:** `vault_nix_{service}_{secret}` (user edits vault, agent provides command)
- **All containers:** `community.docker.docker_container`, `no-new-privileges:true`, healthchecks, infra variable ports
- **Lint:** `devbox run -- rtk ansible-lint <path>`

## Changelog

- 2026-07-08: Initial task index created with 14 stories across 4 phases
