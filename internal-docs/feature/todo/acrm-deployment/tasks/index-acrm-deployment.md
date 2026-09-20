# Task Index: ACRM nl-Region Deployment

**PRD**: `../feat-202609191733-acrm-deployment.md`
**Research**: `internal-docs/research/service/acrm/` (README, deployment-design, packaging-analysis)
**Implementation guide**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`

## Stories

| Story ID | Title | Phase | Status | Parallel-safe | Dependencies | Dependants | Branch |
|---|---|---:|---|---|---|---|---|
| 01-001 | ACRM monorepo Dockerfile + build/push recipe (acrm repo) | 01 | [x] Done | true | — | 05-001 (deploy only) | `feature/current/acrm-deployment/story-01-001-acrm-dockerfile` |
| 02-001 | Shared + levonk infra vars, services.yml, catalogs | 02 | [x] Done | true | — | 03-001, 04-001, 05-001 | `feature/current/acrm-deployment/story-02-001-infra-vars-catalog` |
| 03-001 | `ai-acrm` Ansible role (Windows deploy + postgres + migrations) | 03 | [x] Done | false | 02-001 | 04-001, 05-001 | `feature/current/acrm-deployment/story-03-001-acrm-role` |
| 04-001 | Traefik (Windows) dynamic config + DNS records | 04 | [x] Done | false | 02-001, 03-001 | 05-001 | `feature/current/acrm-deployment/story-04-001-traefik-dns` |
| 05-001 | deploy-acrm.yml playbook + just/devbox recipes | 05 | [x] Done | false | 03-001, 04-001 | — | `feature/current/acrm-deployment/story-05-001-playbook-justfile` |

## Notes

- **01-001 executes in the acrm repo** (`~/p/gh/levonk/acrm`), not infrahub —
  the Dockerfile must live at the monorepo root for pnpm `workspace:*`
  resolution, and `scripts/build-and-push-images.sh` only supports contexts
  under `shared/active/03-container/services/`. Everything else is infrahub.
- **Vault handoff (blocking for live deploy, not for code)**: the user must
  add `vault_acrm_api_key` + `vault_acrm_postgres_password` to
  `infrahub-levonk-all.vault.yml` before the first real deploy — see the PRD
  "Vault Handoff" section for the copyable `docker run` vault-edit command.
- **Phase ordering**: 02 → 03 → 04 → 05. Story 01 is independent and can run
  in parallel with all of them; a live deploy additionally requires the image
  to exist in `100.90.22.85:5000`.
- **DNS mechanism**: add both records to `configure-cloudflare-dns.yml`'s
  `cloudflare_dns_records` (canonical list) AND a `dns`-tagged Phase-0 play in
  `deploy-acrm.yml` (n8n/paperclip pattern). Both domains CNAME →
  `dtop202311.tale-grouper.ts.net` — do NOT copy stirling-api's A record; the
  `infra_tailscale_ip_windows_docker` var currently holds the OCI IP
  (100.90.22.85) instead of dtop202311's real IP (100.81.103.34). Fixing that
  var is flagged in the PRD open questions.
- **Backup**: deferred — first nl postgres; see PRD "Deferred Items".

## Status Legend

- `[ ]` Todo
- `[~]` In-Progress
- `[x]` Done
- `[!]` Blocked

## Deployment Verification (post-deploy checklist)

- Containers: `localnet-acrm-web`, `localnet-acrm-postgres` — healthy on
  dtop202311 (`docker inspect` via `DOCKER_HOST: ssh://…`)
- `https://acrm.nl.levonk.com` → Authelia challenge, then dashboard
- `https://acrm-api.nl.levonk.com/api/v1/suggest` → 401 without
  `x-acrm-api-key`, non-401 with it
- Postgres: `\dt` shows drizzle-migrated tables (`graph_nodes`,
  `graph_edges`, `messages`, `typing_events`, `edit_versions`)
- `dig +short acrm-api.nl.levonk.com` → `dtop202311.tale-grouper.ts.net`
