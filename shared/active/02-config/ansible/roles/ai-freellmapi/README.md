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

After deployment, the first account must be created through the dashboard:
1. Open `https://freellmapi.<base>` in a browser
2. Create the first account (email + password)
3. A one-time setup code is printed in the server logs — check with:
   ```bash
   devbox run -- rtk ansible -m command -a "docker logs {{ ai_freellmapi_container_name }} 2>&1 | grep 'setup code'" oci-cloud-server
   ```
4. Add provider API keys on the Keys page
5. Grab the unified `freellmapi-...` API key from the Keys page header
6. Point OpenAI clients at `https://freellmapi.<base>/v1` with that key
