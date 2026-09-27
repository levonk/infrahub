# ai-freellmapi

Deploys [FreeLLMAPI](https://github.com/tashfeenahmed/freellmapi) — a free-tier
LLM aggregator that aggregates 34+ providers behind a single OpenAI-compatible
`/v1` endpoint with automatic fallover, per-key rate tracking, and a
self-updating model catalog.

## Configuration

All variables reference `infra_*` infrastructure variables with safe defaults.
See `defaults/main.yml` for the full list.

### Required Vault Secret

- `vault_ai_freellmapi_encryption_key` — 64-char hex key for AES-256-GCM
  encryption of provider API keys stored in SQLite. Generate with:
  ```bash
  openssl rand -hex 32
  ```

### Optional Vault Secrets (declarative provisioning)

- `vault_ai_freellmapi_admin_email` / `vault_ai_freellmapi_admin_password` —
  when both are set, they are merged into `FREEAPI_CONFIG_JSON` as the native
  `admin` field and the server creates the first dashboard account during
  boot (see Declarative Provisioning below). Leave unset to keep the manual
  browser setup flow.
- `vault_ai_freellmapi_license_key` — freellmapi.co Premium license key.
  Merged into `FREEAPI_CONFIG_JSON` as the native `license` field; the server
  validates it against the license service and activates detached at boot
  (unreachable license service never delays startup). An identical stored key
  short-circuits; a changed key re-activates (rotation).
- `vault_ai_freellmapi_config` — dict rendered to `FREEAPI_CONFIG_JSON` and
  applied idempotently by the server on every boot (provider keys, custom
  providers, model overrides, fallback chain, routing strategy). Shape:
  ```yaml
  vault_ai_freellmapi_config:
    keys:
      - {platform: groq, key: "gsk_...", label: main}
      - {platform: google, key: "AIza...", enabled: true}
    routing: {strategy: balanced}
  ```
  Note: the rendered JSON lives in the container env (`docker inspect`-visible
  to host root) — same exposure class as `ENCRYPTION_KEY`.

## Declarative Provisioning

Since upstream **v0.12.0** (PR
[tashfeenahmed/freellmapi#1291](https://github.com/tashfeenahmed/freellmapi/pull/1291)),
`admin` and `license` are first-class `FREEAPI_CONFIG_JSON` fields. The role
merges the vault credentials into the config JSON (`ai_freellmapi_config_effective`),
which the server applies inside the boot-time config pass — before
`app.listen()` and before the `userCount() === 0` check that mints a setup
code. Consequences:

- A configured admin **closes the unauthenticated setup window entirely** — no
  setup code is minted and `/api/auth/setup` answers 409 from the first
  request.
- Once any user exists, the `admin` block degrades to a warning — config can
  never take over a claimed install. It only matters on a fresh/empty data
  volume (deterministic rebuilds).
- `license` activates detached, so an unreachable license service never
  delays boot; the live catalog sync is kicked after activation.

The image tag is pinned (`v0.12.0`) because these fields only exist on
upstream >= v0.12.0.

## Health Check

The container health check uses `GET /api/ping` which returns 200 when the
server is ready.

## Monitoring

- **Health endpoint**: `/api/ping`
- **Pipeline**: `ai`
- **Stage**: `gateway`
- **Metrics**: No native Prometheus metrics endpoint

## Backup

FreeLLMAPI stores its SQLite database (with encrypted provider keys) in a
Docker volume at `/app/server/data`. The database cannot be regenerated from
Ansible config — it contains user-added provider API keys and settings.

Use file-based backup of the data volume:
```bash
docker run --rm -v {{ ai_freellmapi_volume_name }}:/data:ro -v /opt/localnet/backup/freellmapi:/backup alpine tar czf /backup/freellmapi-$(date +%Y%m%d).tar.gz -C /data .
```

FreeLLMAPI also supports built-in encrypted backups via the
`FREEAPI_DB_BACKUP_PATH` environment variable.

## First-Run Setup

With `vault_ai_freellmapi_admin_email` + `vault_ai_freellmapi_admin_password`
set, the role creates the account automatically — just sign in at
`https://freellmapi.<base>` and grab the unified `freellmapi-...` API key
from the Keys page header to point OpenAI clients at
`https://freellmapi.<base>/v1`.

Manual fallback (no vault credentials): open the dashboard, create the first
account with the one-time setup code from the server logs:
```bash
devbox run -- rtk ansible -m command -a "docker logs {{ ai_freellmapi_container_name }} 2>&1 | grep 'setup code'" oci-cloud-server
```
