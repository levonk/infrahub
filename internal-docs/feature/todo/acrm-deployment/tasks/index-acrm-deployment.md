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

All items verified — deployment complete (play recap `ok=119 changed=35
failed=0`, Traefik healthy, all 12 managed-domain certs valid):

- [x] Containers: `localnet-acrm-web`, `localnet-acrm-postgres` — healthy on
  dtop202311 (`docker inspect` via `DOCKER_HOST: ssh://…`)
- [x] `https://acrm.nl.levonk.com` → 302 to `auth.levonk.com` (Authelia
  challenge), `authelia_session` cookie set
- [x] `https://acrm-api.nl.levonk.com` → reaches app directly (no Authelia
  redirect); POST `/api/v1/message` → 401 `{"error":"Unauthorized"}` without
  `x-acrm-api-key`, 200 with it — full vertical slice returned
  `messageId` + `graphNodeId` + `safetyLatch` evaluation
- [x] Postgres `\dt`: `graph_nodes`, `graph_edges`, `messages`,
  `typing_events`, `edit_versions` all present (drizzle migrations ran)
- [x] `acrm-nl.yml` present in traefik-windows dynamic config volume;
  both `acrm.nl` and `acrm-api.nl` certs valid (Let's Encrypt, cert
  validation task passed)
- [x] `dig +short acrm-api.nl.levonk.com` → `dtop202311.tale-grouper.ts.net`

### Deploy-time incidents resolved

- Cloudflare 400 on record create: `cloudflare_dns_ttl` string→int fix in
  `cloudflare-dns` role (`create_record.yml`/`update_record.yml`)
- Windows daemon lacked `insecure-registries`: bootstrap task wrote to the
  wrong profile (`ansible` acct vs interactive `micro`) and emitted a
  UTF-8 BOM — both fixed (`ac0086a3`, `d20e291c`); Docker Desktop relaunch
  requires the interactive session (user handoff)
- macOS keychain SecurityAgent ACL prompt blocked all `docker pull`s
  (incl. `DOCKER_CONFIG`-clean ones) until user clicked "Always Allow"
- Transient SSH timeout during traefik seed-exec; idempotent retry succeeded
- Stale `ansible_python_interpreter` (`C:\Program Files\Python312`) moved to
  host level; path still nonexistent — any Python-dispatched module will
  fail, `win_shell`/delegated tasks unaffected
