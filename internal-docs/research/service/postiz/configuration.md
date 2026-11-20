# Postiz — Configuration

Postiz is configured **entirely via environment variables**; any change needs
an app restart (container recreate). Vars can be passed directly
(`docker_container env`/`env_file`) or via an env file mounted at `/config`.

Canonical upstream list: `.env.example` in `gitroomhq/postiz-app` and
https://docs.postiz.com/self-host/configuration/reference

## Required variables (validated on boot)

| Variable | Meaning | Secret? |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string (Prisma), e.g. `postgresql://postiz-user:PASS@postiz-postgres:5432/postiz-db-local` | yes (contains password) |
| `REDIS_URL` | Redis connection string, e.g. `redis://postiz-redis:6379` | no (no auth in ref) |
| `JWT_SECRET` | Long random string signing session JWTs. Rotating invalidates all sessions | **yes** |
| `FRONTEND_URL` | URL the **browser** uses to reach Postiz; OAuth redirect base + email links. `https://postiz.nl.levonk.com` | no |
| `NEXT_PUBLIC_BACKEND_URL` | URL the **browser** uses for the API. On the all-in-one image: `FRONTEND_URL` + `/api` → `https://postiz.nl.levonk.com/api` | no |
| `BACKEND_INTERNAL_URL` | URL the frontend SSR server uses to reach the backend **inside the container** — always `http://localhost:3000` | no |

## Behaviour variables (recommended/optional)

| Variable | Default | Meaning |
|----------|---------|---------|
| `MAIN_URL` | falls back to `FRONTEND_URL` | Primary URL for absolute links in emails/SEO. Set = `FRONTEND_URL` |
| `IS_GENERAL` | — | Branding/product switch; official compose sets `"true"` (required for now) |
| `RUN_CRON` | unset | When set, the backend runs scheduled-task workers. Set `true` on the single container |
| `TEMPORAL_ADDRESS` | — | `host:port` of Temporal frontend → `temporal:7233`. Required since v2.12.0 |
| `TEMPORAL_NAMESPACE` | `default` | Temporal namespace |
| `DISABLE_REGISTRATION` | `false` | `true` = only first signup allowed, then sign-up closes. ⚠️ also disables OIDC/OAuth sign-in |
| `API_LIMIT` | `90` (compose ships `30`) | Per-hour public-API post limit, instance-wide |
| `DISALLOW_PLUS` | unset | Hides paid-plan upsell UI (self-host cosmetic) |
| `DISABLE_SSRF_PROTECTION` | unset | `true` allows server-side fetches to private IPs (self-hosted providers like WordPress/Listmonk on LAN). Only for trusted single-tenant installs |
| `NOT_SECURED` | unset | Dev only — **never set in production** |
| `HTTPS_PROXY` / `HTTP_PROXY` | unset | Outbound proxy for social API calls |
| `PORT` | `3000` | Backend bind port (internal) |
| `EXCLUDE_QUEUE`, `WORKER_CONCURRENCY_DIVIDER` | — | Temporal worker tuning; irrelevant at our scale |

## Storage

| Variable | Meaning |
|----------|---------|
| `STORAGE_PROVIDER` | `local` (default) or `cloudflare` (R2) |
| `UPLOAD_DIRECTORY` | Filesystem path for local writes → `/uploads` |
| `NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY` | Public URL prefix for uploaded files → `/uploads`. Docs name this the real var; the shipped compose also sets `NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads` — **set both** to be safe |
| `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_ACCESS_KEY` / `CLOUDFLARE_SECRET_ACCESS_KEY` / `CLOUDFLARE_BUCKETNAME` / `CLOUDFLARE_BUCKET_URL` / `CLOUDFLARE_REGION` | R2 credentials if `cloudflare` chosen (all secrets) |

Local storage: frontend rewrites `/uploads/:path*` → backend `/api/uploads/:path*`.
Public HTTPS reachability of `/uploads` is required for pull-from-URL
providers (TikTok etc.) — satisfied via Traefik.

## Social provider keys (per-platform, all optional-but-needed-to-connect)

Every OAuth provider needs a developer app registered on that platform; the
resulting key/secret pair goes in env. Platforms shown in "Add Channel" even
when unconfigured (connect just fails).

Redirect URI shape is **always** the same — register this per provider app:

```
{FRONTEND_URL}/integrations/social/{provider}
→ https://postiz.nl.levonk.com/integrations/social/x        (X/Twitter)
→ https://postiz.nl.levonk.com/integrations/social/linkedin
→ https://postiz.nl.levonk.com/integrations/social/instagram
… provider slugs per docs (note odd ones: farcaster = `wrapcast`, GMB = `gmb`)
```

Several providers (Slack, TikTok, Threads, Instagram standalone, VK) **require
HTTPS redirect URIs** — our TLS fronting covers this. (Plain-HTTP dev URLs are
wrapped through third-party `redirectmeto.com`; irrelevant once `FRONTEND_URL`
is `https://`.)

| Provider | Env vars (all secrets) |
|----------|------------------------|
| X (Twitter) | `X_API_KEY`, `X_API_SECRET`, `X_URL` |
| LinkedIn (+ Page) | `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` |
| Facebook / Instagram (FB Business) | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` |
| Instagram standalone | `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET` |
| Threads | `THREADS_APP_ID`, `THREADS_APP_SECRET` |
| YouTube / Google My Business | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` (+ optional `GOOGLE_GMB_*` override) |
| TikTok | `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` (or `TIKTOK_BUSINESS_*`) |
| Reddit | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` |
| Pinterest | `PINTEREST_CLIENT_ID`, `PINTEREST_CLIENT_SECRET` |
| Discord | `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`, `DISCORD_BOT_TOKEN_ID` |
| Slack | `SLACK_ID`, `SLACK_SECRET` |
| Telegram | `TELEGRAM_TOKEN`, `TELEGRAM_BOT_NAME` |
| Mastodon | `MASTODON_URL`, `MASTODON_CLIENT_ID`, `MASTODON_CLIENT_SECRET` |
| Tumblr / Dribbble / Twitch / Kick / VK / Whop / Farcaster(Neynar) / MeWe | per-provider `*_CLIENT_ID`/`*_SECRET` — see docs |
| GitHub sign-in | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| Beehiiv / Listmonk | newsletter creds |

User-supplied-credential providers needing **no admin env**: Bluesky, Lemmy,
Nostr, Medium, Dev.to, Hashnode, WordPress, Listmonk, Moltbook, Skool
(browser extension).

## Email

`EMAIL_PROVIDER` = `resend` | `ses` | `nodemailer`. **If unset, users are
auto-activated** (no verification emails). Setting any provider turns on
activation-required flow. `nodemailer` needs `EMAIL_HOST/PORT/USER/PASS/
SECURE` + `EMAIL_FROM_ADDRESS/EMAIL_FROM_NAME` — SMTP secrets go to vault.

## Channel-token encryption at rest (recommended)

| Variable | Meaning |
|----------|---------|
| `ENCRYPTION_PROVIDER` | `local` or `aws-kms`. **Unset = OAuth tokens stored plaintext in Postgres** |
| `ENCRYPTION_KEY` | 32-byte base64 key for `local` (`openssl rand -base64 32`) → vault |
| `ENCRYPTION_KMS_*` | AWS KMS variant |
| `ENCRYPTION_READ_ONLY` | rolling-enablement flag |

Losing the key means every channel must be reconnected — vault + backup it.

## OIDC / generic OAuth sign-in (optional)

`POSTIZ_GENERIC_OAUTH=true` + `POSTIZ_OAUTH_URL`, `POSTIZ_OAUTH_AUTH_URL`,
`POSTIZ_OAUTH_TOKEN_URL`, `POSTIZ_OAUTH_USERINFO_URL`,
`POSTIZ_OAUTH_CLIENT_ID`, `POSTIZ_OAUTH_CLIENT_SECRET` (secret),
`POSTIZ_OAUTH_SCOPE` (default `openid profile email`),
`NEXT_PUBLIC_POSTIZ_OAUTH_DISPLAY_NAME`, `NEXT_PUBLIC_POSTIZ_OAUTH_LOGO_URL`.
E.g. Authentik. ⚠️ incompatible with `DISABLE_REGISTRATION=true`.

## Other optional knobs

- `OPENAI_API_KEY` (secret) — AI copilot/image gen.
- `NEXT_PUBLIC_POLOTNO` — in-app design editor key.
- `DISCORD_BOT_TOKEN_ID`, `NEYNAR_*`, `BEEHIIVE_*`, `LISTMONK_*`.
- Short-link providers: `DUB_*`, `SHORT_IO_SECRET_KEY`, `KUTT_*`, `LINK_DRIP_*`.
- Payments: **leave all `STRIPE_*` unset** — presence of
  `STRIPE_PUBLISHABLE_KEY` flips the whole app into billed mode with plan caps.
  Dead vars in shipped compose (`FEE_AMOUNT`, `STRIPE_SIGNING_KEY_CONNECT`,
  `NX_ADD_PLUGINS`, `SLACK_SIGNING_SECRET`) read by nothing — omit.
- Analytics: `NEXT_PUBLIC_SENTRY_DSN`, `NEXT_PUBLIC_POSTHOG_*` — skip.
- `EXTENSION_ID` — Chrome extension for cookie-based integrations.
