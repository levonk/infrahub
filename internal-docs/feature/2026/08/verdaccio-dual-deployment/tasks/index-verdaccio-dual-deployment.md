# Task Index: Verdaccio Dual-Deployment

| Story | Name | Status | Depends | Branch |
|-------|------|--------|---------|--------|
| 01-001 | Shared infrastructure schemas | [x] Done | — | feature/current/verdaccio-dual-deployment/story-01-001-shared-infra-schemas |
| 01-002 | Client infrastructure values + DNS | [x] Done | 01-001 | feature/current/verdaccio-dual-deployment/story-01-002-client-infra-dns |
| 01-003 | Vault secrets handoff | [x] Done | 01-001 | feature/current/verdaccio-dual-deployment/story-01-003-vault-secrets |
| 01-004 | Ansible role artifact-verdaccio | [x] Done | 01-001, 01-003 | feature/current/verdaccio-dual-deployment/story-01-004-ansible-role |
| 01-005 | Traefik dynamic config templates | [x] Done | 01-002, 01-004 | feature/current/verdaccio-dual-deployment/story-01-005-traefik-routing |
| 01-006 | Deployment + validation playbooks | [x] Done | 01-004, 01-005 | feature/current/verdaccio-dual-deployment/story-01-006-playbooks |
| 01-007 | Service catalog + cleanup old scaffolding | [x] Done | 01-001, 01-004 | feature/current/verdaccio-dual-deployment/story-01-007-catalog-cleanup |

## Dependency Graph

```
01-001 (shared schemas)
  ├── 01-002 (client infra + DNS)
  ├── 01-003 (vault secrets)
  └── 01-007 (catalog + cleanup)
01-003 (vault secrets)
  └── 01-004 (ansible role)
01-004 (ansible role)
  ├── 01-005 (traefik routing)
  └── 01-006 (playbooks)
01-005 (traefik routing)
  └── 01-006 (playbooks)
```

## Parallelism

- 01-002, 01-003, 01-007 can run in parallel after 01-001 (different files)
- 01-004 depends on 01-001 + 01-003
- 01-005 depends on 01-002 + 01-004
- 01-006 depends on 01-004 + 01-005
