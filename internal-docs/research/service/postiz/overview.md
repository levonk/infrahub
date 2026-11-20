# Postiz — Overview

## What it is

Postiz is an open-source, self-hostable social media scheduling and management
platform — a Buffer/Hootsuite alternative. It schedules and publishes posts to
30+ social platforms from one calendar, with AI content generation, analytics,
team collaboration, an API, and an MCP server for agent-driven workflows.

- Repo: https://github.com/gitroomhq/postiz-app (~41.5k stars, TypeScript monorepo)
- Docs: https://docs.postiz.com
- Official compose repo: https://github.com/gitroomhq/postiz-docker-compose
- License: **AGPL-3.0** (see `security.md` for implications)
- Activity: very active — releases tagged ~weekly (v2.26.0 released 2026-11-13);
  heavy daily commit volume
- Hosted counterpart: Postiz Cloud (postiz.com). The self-hosted image is the
  same codebase with no feature gating — billing/plan limits only activate if a
  `STRIPE_PUBLISHABLE_KEY` is set; without Stripe keys the instance behaves as
  the top tier.

## Feature highlights

- Multi-channel composer: one post fanned out to X, LinkedIn, Facebook,
  Instagram, Threads, YouTube, TikTok, Reddit, Pinterest, Mastodon, Bluesky,
  Discord, Slack, Telegram, Tumblr, WordPress, newsletters (Beehiiv, Listmonk),
  and more. 10 platforms (Bluesky, Lemmy, WordPress, etc.) need no admin
  configuration — each user supplies credentials in-app.
- Calendar with posting time slots, repeat cycles, drafts, approvals.
- Analytics per post/channel (where platform APIs expose metrics).
- AI copilot / image generation (OpenAI key optional), in-app design editor.
- Team/orgs, invite links, client groups.
- Public API + MCP server + CLI for automation.
- Webhooks, RSS auto-posting, "plugs" (auto-repost/comment on performance).

## Architecture at a glance

Postiz is a TypeScript monorepo (Nx) with three main services, **all bundled
into a single Docker container** that talk to each other over internal HTTP:

| Service | Role |
|---------|------|
| Frontend | Next.js web UI; SSR; serves `/uploads/*` via rewrite to backend |
| Backend | NestJS API (`/api/*`), Prisma ORM, triggers Temporal workflows |
| Orchestrator | In-process Temporal worker — runs scheduled posts, token refresh, email digests |

External dependencies (run as separate containers or external services):

| Service | Required? | Purpose |
|---------|-----------|---------|
| PostgreSQL ≥14 | Required | All app data (users, channels, posts, OAuth tokens) via Prisma |
| Redis ≥6 | Required | Queues, rate limiting, short-lived caches, session state |
| Temporal | Required since v2.12.0 | Durable workflow engine for scheduling/retries |
| Object storage | Optional | Cloudflare R2 **or** local filesystem (`STORAGE_PROVIDER=local`) |

The official compose runs a full Temporal dev-grade stack:
`temporalio/auto-setup` + its own Postgres + Elasticsearch + Temporal UI.
Postiz only needs Temporal's gRPC frontend (`temporal:7233`).

## Fit for this deployment

- Single public container, one port (`5000`) — simple Traefik fronting at
  `postiz.nl.levonk.com`. All app traffic (UI, `/api`, OAuth callbacks,
  `/uploads`) flows through that one entrypoint.
- Everything else is internal-only: Postgres, Redis, Temporal stack. Only the
  postiz container joins the Traefik-reachable network.
- Deployment shape is ~6 containers (app, postgres, redis, temporal,
  temporal-postgres, temporal-es) plus 2 optional (temporal-ui, admin-tools) —
  heavier than most self-hosted schedulers because of Temporal.
- Heaviest prerequisite work is **social provider developer apps**: every OAuth
  platform (X, LinkedIn, Meta, TikTok, Google, …) needs its own registered app
  and key pair in env vars. Without keys the platform appears in the UI but
  connect fails.
