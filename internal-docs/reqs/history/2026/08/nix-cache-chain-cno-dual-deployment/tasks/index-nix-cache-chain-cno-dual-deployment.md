# Task Index: Nix Cache Chain CNO Dual-Deployment

| Story | Name | Status | Depends | Branch |
|-------|------|--------|---------|--------|
| 01-001 | Shared infra schemas (cno) | [x] Done | — | feature/current/nix-cache-chain-cno-dual-deployment/story-01-001-shared-infra-schemas |
| 01-002 | Client infra values + DNS | [x] Done | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-002-client-infra-dns |
| 01-003 | Nix flakes aarch64-linux support | [x] Done | — | feature/current/nix-cache-chain-cno-dual-deployment/story-01-003-flake-aarch64 |
| 01-004 | Refactor nix-harmonia role (dual-deploy) | [x] Done | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-004-harmonia-role |
| 01-005 | Refactor nix-ncps role (dual-deploy) | [x] Done | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-005-ncps-role |
| 01-006 | Refactor nix-ncro role (dual-deploy) | [x] Done | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-006-ncro-role |
| 01-007 | Traefik dynamic config (cno) | [x] Done | 01-002 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-007-traefik-routing |
| 01-008 | Update playbook for dual-target | [x] Done | 01-004, 01-005, 01-006 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-008-playbook |
| 01-009 | Service catalog + regenerate | [x] Done | 01-001 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-009-catalog |
| 01-010 | Build ARM64 images on OCI | [x] Done | 01-003 | feature/current/nix-cache-chain-cno-dual-deployment/story-01-010-build-images |

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

## Completion Notes

All 10 stories were implemented in prior commits (see git history: `1a2eb24`,
`f7a8c642`, `b1e6ecff`, `13cf7b1f`, `f68a5609`). The task index was not updated
at the time. This update marks all stories `[x] Done` after verifying:

- All shared infra schemas include cno entries (ports, domains, networks, storage)
- Client infra values include cno DNS + Tailscale FQDNs
- Nix flakes support both `x86_64-linux` and `aarch64-linux`
- All three roles (`nix-harmonia`, `nix-ncps`, `nix-ncro`) have dual-deploy
  (`deploy-linux.yml` + `deploy-windows.yml`)
- Traefik dynamic config template for `nixcache.cno.levonk.com` exists
- Playbook `deploy-nix-cache-chain.yml` targets both `cloud_servers` and
  `windows_docker_hosts`
- Service catalog includes cno entries
- `ansible-lint` passes (3 lint violations fixed in this session: meta-no-tags
  in nix-harmonia, command-instead-of-shell in nix-ncps deploy-windows.yml)
- `ansible-playbook --syntax-check` passes on both playbooks
- No hardcoded IPs or ports in any nix-cache-chain role file
