# Task Index: Nix Cache Chain CNO Dual-Deployment

| Story | Name | Status | Depends | Branch |
|-------|------|--------|---------|--------|
| 01-001 | Shared infra schemas (cno) | [ ] Todo | — | feature/current/nix-cache-chain-cno-dual-deployment/story-01-001-shared-infra-schemas |
| 01-002 | Client infra values + DNS | [ ] Todo | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-002-client-infra-dns |
| 01-003 | Nix flakes aarch64-linux support | [ ] Todo | — | feature/current/nix-cache-chain-cno-dual-deployment/story-01-003-flake-aarch64 |
| 01-004 | Refactor nix-harmonia role (dual-deploy) | [ ] Todo | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-004-harmonia-role |
| 01-005 | Refactor nix-ncps role (dual-deploy) | [ ] Todo | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-005-ncps-role |
| 01-006 | Refactor nix-ncro role (dual-deploy) | [ ] Todo | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-006-ncro-role |
| 01-007 | Traefik dynamic config (cno) | [ ] Todo | 01-002 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-007-traefik-routing |
| 01-008 | Update playbook for dual-target | [ ] Todo | 01-004, 01-005, 01-006 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-008-playbook |
| 01-009 | Service catalog + regenerate | [ ] Todo | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-009-catalog |
| 01-010 | Build ARM64 images on OCI | [ ] Todo | 01-003 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-010-build-images |

## Dependency Graph

```
01-001 (shared schemas)
  ├── 01-002 (client infra + DNS)
  ├── 01-004 (harmonia role)
  ├── 01-005 (ncps role)
  ├── 01-006 (ncro role)
  └── 01-009 (catalog)
01-002 (client infra + DNS)
  └── 01-007 (traefik routing)
01-003 (flake aarch64) — independent
  └── 01-010 (build images)
01-004, 01-005, 01-006 (roles)
  └── 01-008 (playbook)
01-007 (traefik)
  └── 01-008 (playbook)
```

## Parallelism

- 01-001, 01-003 can run in parallel (no deps)
- 01-002, 01-004, 01-005, 01-006, 01-009 can run in parallel after 01-001
- 01-007 after 01-002
- 01-008 after 01-004 + 01-005 + 01-006 + 01-007
- 01-010 after 01-003
