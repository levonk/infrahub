# Postiz — Security

## License

**AGPL-3.0** (GNU Affero General Public License v3; changed from Apache-2.0
earlier in the project's history — GitHub repo metadata confirms `AGPL-3.0`).

- Network-copyleft: if we **modify** Postiz and let users interact with it over
  a network, the modified source must be offered to those users. Running the
  unmodified upstream image for internal use carries no distribution
  obligation — normal self-hosting is fine.
- No self-hosting feature restrictions: the same image as Postiz Cloud; no
  license key, no plan gating (billing only activates with `STRIPE_*` set).
- AGPL is contagious only for derivative works; our Ansible/env config is not
  a derivative work.

## Secrets inventory → Ansible vault

All of these belong in `infrahub-levonk-all.vault.yml`:

| Secret | Purpose |
|--------|---------|
| `vault_postiz_jwt_secret` | `JWT_SECRET` — session signing |
| `vault_postiz_postgres_password` | app DB password inside `DATABASE_URL` |
| `vault_postiz_encryption_key` | `ENCRYPTION_KEY` (32B base64) — encrypts social OAuth tokens at rest |
| `vault_postiz_<provider>_client_id/secret` | each social platform's OAuth pair |
| `vault_postiz_smtp_*` | if `EMAIL_PROVIDER=nodemailer` |
| `vault_postiz_openai_api_key` | if AI features enabled |
| `vault_fwknop_*`-style naming | follow existing `vault_<service>_<name>` convention |

Also: Temporal's own Postgres has a `temporal` user password in env
(`POSTGRES_PWD`) — vault it too (reference uses literal `temporal`; change it).

## Token-at-rest posture (important)

`ENCRYPTION_PROVIDER` **unset = every connected channel's OAuth access/refresh
token is stored as plaintext in Postgres**. Set `ENCRYPTION_PROVIDER=local` +
`ENCRYPTION_KEY` from day one — rotating in later needs a token-re-encrypt
workflow. Key loss = all channels must reconnect; vault and back it up.

## Registration & access control

- `DISABLE_REGISTRATION=true` after first account → closes public sign-up.
  ⚠️ It also disables OIDC/generic-OAuth login — pick one strategy:
  password login + disabled registration, **or** OIDC (Authentik) + open
  registration gated by the IdP.
- Default behavior with no `EMAIL_PROVIDER`: signups auto-activate — anyone
  reaching the instance can create an account immediately. Either disable
  registration after bootstrap or configure email + consider an SSO layer.

## Built-in protections worth keeping

- **SSRF guard**: server-side fetches (upload-from-url, self-hosted providers
  like WordPress/Mastodon/Listmonk) block private/loopback/link-local IPs by
  default. Leave `DISABLE_SSRF_PROTECTION` **unset** unless a provider is on
  the LAN — and only then because the instance is single-tenant trusted.
- `NOT_SECURED` exists — never set it.
- Provider connect flows use state-checked OAuth; HTTPS `FRONTEND_URL` avoids
  the `redirectmeto.com` third-party bounce entirely.
- Backend JSON body limit is 50 MB on post routes (app-enforced).

## Exposure surface

| Endpoint | Exposure | Note |
|----------|----------|------|
| `postiz.nl.levonk.com` → `:5000` | public via Traefik | UI, `/api`, `/integrations` OAuth callbacks, `/uploads` media, `/webhooks`, `/mcp` — **must stay public** (providers pull media + OAuth callbacks) |
| Postgres / Redis / Temporal / ES | internal Docker networks only | publish nothing |
| Temporal gRPC `7233` | internal only | reference binds `127.0.0.1`; don't even publish |
| Temporal UI `8080` | loopback or omit | no auth on Temporal UI — never proxy publicly |

## Traefik / transport notes

- Single router `Host(postiz.nl.levonk.com)` → service port `5000`,
  `websecure` entrypoint + TLS. No path-splitting needed on the all-in-one
  image (backend lives under `/api` on the same port).
- Standard headers (`Host`, `X-Forwarded-For`, `X-Forwarded-Proto`) are
  handled by Traefik automatically; WS `Upgrade`/`Connection` passthrough is
  default in Traefik (nginx reference adds them explicitly — harmless
  either way; prod app doesn't strictly need WS).
- **Body size**: Traefik has no default request-body limit (unlike nginx's
  1 MB), so media uploads pass; if a buffering middleware is ever added, its
  default `memRequestBodyBytes` can 413 large uploads — bump to ~100 MB.
- Keep `BACKEND_INTERNAL_URL=http://localhost:3000` — it's intra-container,
  TLS terminates at Traefik, and Postiz builds public URLs from
  `FRONTEND_URL`/`NEXT_PUBLIC_BACKEND_URL`, not from the internal one.
- Cookies: sessions are JWT-based on the frontend origin; single-domain
  deploy means no `Domain=` cookie config needed. Do **not** split API onto
  `api.` subdomain unless prepared for CORS/cookie-domain changes.

## Hardening checklist for deploy

- [ ] `ENCRYPTION_PROVIDER=local` + vaulted `ENCRYPTION_KEY`
- [ ] `JWT_SECRET` ≥ 64 random chars, vaulted
- [ ] Real Postgres passwords (app + Temporal), vaulted; Redis internal-only
- [ ] Decide registration strategy; set `DISABLE_REGISTRATION` or OIDC
- [ ] No `STRIPE_*`, no `NOT_SECURED`, no `DISABLE_SSRF_PROTECTION`
- [ ] Only `:5000` reachable via Traefik; nothing else published
- [ ] Pin image to timestamp tag/digest, not `latest`
- [ ] Postgres + uploads volumes in the host backup set
