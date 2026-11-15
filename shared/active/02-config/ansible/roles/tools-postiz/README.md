# tools-postiz

Deploys the Postiz social-media scheduling stack on Windows Docker Desktop
(dtop202311, nl region) via the ssh-tunneled Docker CLI pattern
(`DOCKER_HOST: ssh://…`, `delegate_to: localhost`).

## Containers

| Container | Image | Network | Purpose |
|---|---|---|---|
| `localnet-postiz` | `ghcr.io/gitroomhq/postiz-app:latest` | postiz-network + postiz-temporal-network + traefik-windows-network | All-in-one app (UI `/`, API `/api`, uploads `/uploads`, OAuth `/integrations`) on :5000 |
| `localnet-postiz-postgres` | `postgres:17-alpine` | postiz-network | App database |
| `localnet-postiz-redis` | `redis:7.2-alpine` | postiz-network | Queues/cache/sessions |
| `localnet-postiz-temporal` | `temporalio/auto-setup:1.28.1` | postiz-temporal-network | Workflow engine (`ENABLE_ES=true`) |
| `localnet-postiz-temporal-postgres` | `postgres:16-alpine` | postiz-temporal-network | Temporal persistence |
| `localnet-postiz-temporal-elasticsearch` | `elasticsearch:7.17.27` | postiz-temporal-network | Advanced visibility — required: Postiz registers more Text search attributes than SQL visibility allows |

## Required vault keys (user handoff)

Add to `infrahub-levonk-all.vault.yml` via `scripts/edit-vault.sh` — the role
asserts all four are non-empty:

```yaml
vault_postiz_jwt_secret: "<openssl rand -hex 32>"
vault_postiz_postgres_password: "<openssl rand -hex 24>"
vault_postiz_temporal_postgres_password: "<openssl rand -hex 24>"
vault_postiz_encryption_key: "<openssl rand -base64 32>"
```

`vault_postiz_encryption_key` must **base64-decode to exactly 32 bytes** —
the app decodes it, then fails fast with "The key of the local encryption
provider has to be 32 bytes" if the decoded length is wrong. Use
`openssl rand -base64 32` (44 chars → 32 bytes). Raw 32-char ASCII or hex
strings decode to the wrong length.

## Key variables

| Variable | Default | Notes |
|---|---|---|
| `tools_postiz_enabled` | `true` | Master toggle |
| `tools_postiz_disable_registration` | `false` | Set `true` after first account created (upstream also disables OIDC) |
| `tools_postiz_image_tag` | `latest` | Upstream has no semver tags; pin by digest to freeze |
| `tools_postiz_host_port` | `infra_port_tools_postiz_host` (4539) | Tailnet debugging; Traefik is the real path |
| `tools_postiz_verify_health` | `true` | Wait for container health at end |

## Notes

- Temporal `dynamicconfig/development-sql.yaml` is delivered via a named
  volume populated by a one-shot `alpine:3` init container (idempotent —
  skipped when the file already exists). No Windows host bind-mounts.
- Prisma migrations run inside the app container at boot — no separate
  migrate step. Keep backups before bumping the image tag.
- `ENCRYPTION_PROVIDER=local` + `ENCRYPTION_KEY` keeps provider OAuth
  tokens encrypted at rest (upstream default is plaintext).
- `/uploads/*` must be publicly reachable for providers that pull media by
  URL (TikTok, Instagram). The nl domain is tailnet-only — those providers
  will fail until the domain is publicly exposed (e.g. cloudflared tunnel).
- Never set `NOT_SECURED`, `DISABLE_SSRF_PROTECTION`, or any `STRIPE_*`
  variable.

## Usage

```bash
just ansible-deploy-postiz
# or directly:
ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-postiz.yml \
  --vault-password-file ~/.ansible/vault_password
```
