# Task Index: Postiz nl-Region Deployment

**PRD**: `../feat-202611131708-postiz-deployment.md`
**Research**: `internal-docs/research/service/postiz/` (overview, deployment,
configuration, security, alternatives)
**Implementation guide**: `.agents/workflows/infrahub-add-new-service.md`

## Stories

| Story ID | Title | Phase | Status | Parallel-safe | Dependencies | Dependants | Branch |
|---|---|---:|---|---|---|---|---|
| 02-001 | Shared + levonk infra vars, services.yml, catalogs | 02 | [ ] Todo | true | — | 03-001, 04-001, 05-001 | `levonk/20261113-postiz` |
| 03-001 | `tools-postiz` Ansible role (Windows deploy, 6 containers) | 03 | [ ] Todo | false | 02-001 | 04-001, 05-001 | `levonk/20261113-postiz` |
| 04-001 | Traefik (Windows) dynamic config + DNS records | 04 | [ ] Todo | false | 02-001, 03-001 | 05-001 | `levonk/20261113-postiz` |
| 05-001 | deploy-postiz.yml playbook + just/devbox recipes | 05 | [ ] Todo | false | 03-001, 04-001 | — | `levonk/20261113-postiz` |

## Notes

- **No Dockerfile story** — upstream `ghcr.io/gitroomhq/postiz-app`
  all-in-one image; Phase 3 (build pipeline) of the impl guide is skipped.
- **Single-workspace execution** — all stories land on
  `levonk/20261113-postiz` in the Orca worktree
  (`/Users/micro/orca/workspaces/infrahub/20261113-postiz`), not per-story
  branches: the files are disjoint and the change set is one coherent
  feature.
- **Vault handoff (blocking for live deploy, not for code)**: user adds
  `vault_postiz_jwt_secret`, `vault_postiz_postgres_password`,
  `vault_postiz_temporal_postgres_password`, `vault_postiz_encryption_key`
  to `infrahub-levonk-all.vault.yml` — see PRD "Vault Handoff".
- **Template**: `ai-acrm` role + `deploy-acrm.yml` + `acrm-nl.yml.j2` are
  the canonical precedents for every story.
- **Phase ordering**: 02 → 03 → 04 → 05.

## Status Legend

- `[ ]` Todo
- `[~]` In-Progress
- `[x]` Done
- `[!]` Blocked

## Deployment Verification (post-deploy checklist)

- [ ] Containers: `localnet-postiz`, `localnet-postiz-postgres`,
  `localnet-postiz-redis`, `localnet-postiz-temporal`,
  `localnet-postiz-temporal-postgres` — healthy on dtop202311
- [ ] `https://postiz.nl.levonk.com` → Postiz UI (valid TLS, no SSO redirect)
- [ ] `https://postiz.nl.levonk.com/api` → responds (not 404/502)
- [ ] `docker logs localnet-postiz` — connected to temporal, no crash loop
