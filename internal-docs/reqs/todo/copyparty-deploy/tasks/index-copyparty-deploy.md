# Task Index: copyparty-deploy

**PRD**: `internal-docs/feature/todo/copyparty-deploy/feat-202608312209-copyparty-deploy.md`

## Stories

| Story ID | Title | Branch | Dependencies | Parallel-safe | Modules | Status |
|----------|-------|--------|--------------|---------------|---------|--------|
| 01-001 | Shared infrastructure schemas for copyparty | `feature/current/copyparty-deploy/story-01-001-shared-infra-schemas` | none | yes | shared-infra | [x] Done |
| 01-002 | Client infrastructure overrides + DNS + service catalog | `feature/current/copyparty-deploy/story-01-002-client-infra-dns-catalog` | 01-001 | yes | client-infra, dns, catalog | [x] Done |
| 02-001 | Create storage-copyparty Ansible role | `feature/current/copyparty-deploy/story-02-001-create-role` | 01-001 | yes | ansible-role | [x] Done |
| 02-002 | Traefik dynamic config + playbook | `feature/current/copyparty-deploy/story-02-002-traefik-playbook` | 01-001, 01-002 | yes | traefik, playbook | [x] Done |

## Execution Order

1. **Phase 1 (parallel)**: 01-001 (shared schemas) + 01-002 (client infra + catalog) — 01-002 depends on 01-001 but can start once 01-001's shared files exist
2. **Phase 2 (parallel)**: 02-001 (Ansible role) + 02-002 (Traefik + playbook) — both depend on Phase 1

## Status Legend

- `[ ] Todo` — not started
- `[~] In-Progress` — currently being worked on
- `[x] Done` — completed
- `[!] Blocked` — blocked (see notes)
