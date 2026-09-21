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
  when both are set, the role creates the first dashboard account
  automatically (see Declarative Provisioning below). Leave unset to keep the
  manual browser setup flow.
- `vault_ai_freellmapi_license_key` — freellmapi.co Premium license key.
  Activated via `POST /api/premium/key`, which validates against the license
  service and switches the install to the live catalog feed. Re-activated only
  when absent or the stored key's mask differs (rotation). Requires the
  account credentials above.
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

The role runs `files/freellmapi-provision.js` inside the container via
`community.docker.docker_container_exec` when admin credentials are set. The
script:

1. `GET /api/auth/status` — skips setup when `needsSetup` is false (idempotent)
2. `POST /api/auth/setup` — creates the first account. The exec'd request is a
   genuine loopback peer (`127.0.0.1` inside the container's netns), so the
   upstream setup-code gate — which checks the socket peer address, not
   `X-Forwarded-For` — is skipped by design, exactly like a browser on the
   same machine.
3. `POST /api/premium/key` — activates the Premium license using the session
   token from setup/login, only when absent or rotated.

Secrets reach the script through the Docker exec API `env` channel — never
argv, never the host process list. The task is `no_log` by default; set
`ai_freellmapi_provision_no_log: false` to debug failures.

Note: `/api/auth/setup` and `/api/premium/key` are internal dashboard routes,
not a documented public API. They are stable (test-covered upstream), but a
future release could change the request shape — pin
`ai_freellmapi_image_tag` to eliminate that risk.

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
