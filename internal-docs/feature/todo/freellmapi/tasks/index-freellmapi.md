# Task Index: FreeLLMAPI Deployment

**PRD**: `../prd.md`
**Implementation guide**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`

## Stories

| ID | Story | Status | Phase |
|----|-------|--------|-------|
| 01-001 | Add shared infrastructure schemas (ports, domains, storage) | [x] Done | 1 |
| 01-002 | Add client infrastructure values + DNS record + service catalog | [x] Done | 2 |
| 01-003 | Add vault secret (encryption key) — user handoff | [x] Done | 4 |
| 01-004 | Create `ai-freellmapi` Ansible role | [x] Done | 5 |
| 01-005 | Create Traefik dynamic config + register in Traefik role | [x] Done | 6 |
| 01-006 | Add to AI pipeline playbook | [x] Done | 8 |
| 01-007 | Regenerate service catalogs + lint check | [x] Done | 2g |

## Status Legend

- `[ ]` Todo
- `[~]` In-Progress
- `[x]` Done
- `[!]` Blocked

## Deployment Verification

- Container: `localnet-ai-freellmapi` — Up, healthy
- Health endpoint: `/api/ping` returns 200
- Traefik routing: `freellmapi.levonk.com` → 301 (redirect to HTTPS)
- Logs: clean, no errors, catalog sync active
- First-run setup code: `A5VXTAJH3Q` (needed to create first account)
