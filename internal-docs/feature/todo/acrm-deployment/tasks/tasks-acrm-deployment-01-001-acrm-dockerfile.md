---
story_id: "01-001"
story_title: "ACRM monorepo Dockerfile + build/push recipe"
story_name: "acrm-dockerfile"
prd_name: "acrm-deployment"
prd_file: "internal-docs/feature/todo/acrm-deployment/feat-202609191733-acrm-deployment.md"
phase: 1
parallel_id: 1
branch: "feature/current/acrm-deployment/story-01-001-acrm-dockerfile"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["docker", "dockerfile", "external-repo"]
priority: "MUST"
risk_level: "medium"
tags: ["docker", "dockerfile", "acrm", "external-repo", "nx", "pnpm"]
due: "2026-09-19"
create-date: "2026-09-19"
update-date: "2026-09-19"
---

## Summary

**External-repo story — execute in `~/p/gh/levonk/acrm`, NOT infrahub.**

Create a monorepo-aware, multi-stage Dockerfile at the **acrm repo root**
plus a root `.dockerignore`, and a `just` recipe that builds and pushes
`localnet-ai-acrm-web:latest` (linux/amd64) to the local registry
(`100.90.22.85:5000`, overridable via `REGISTRY` env).

The existing `apps/active/web/Dockerfile` is **broken for the monorepo**: it
assumes a single-package build context (`COPY package.json pnpm-lock.yaml*`),
so `workspace:*` deps (`@acrm/core`, `@acrm/engines-oss`, `@acrm/ui`) can
never resolve. The build context must be the repo root so
`pnpm-workspace.yaml`, the root `package.json`/`pnpm-lock.yaml`, and the
`apps/active/*` + `packages/active/*` trees are all present.

## Sub-Tasks

- [ ] Write root `Dockerfile` (multi-stage):
  - deps stage: copy `pnpm-workspace.yaml`, root `package.json`,
    `pnpm-lock.yaml`, and each workspace package's `package.json`
    (`apps/active/web`, `packages/active/core`, `packages/active/engines-oss`,
    `packages/active/ui`); `corepack enable pnpm && pnpm install
    --frozen-lockfile`
  - builder stage: copy source, run the web build
    (`pnpm --filter web run build` or `nx run web:build` — note AGENTS.md:
    use `nx:run-commands`/pnpm, NOT the `@nx/next:build` executor)
  - runner stage: node:22-alpine, non-root user, `ENV NODE_ENV=production
    PORT=3000`, copy the built app (remember `distDir: 'dist'` in
    `next.config.js` — the build output is `apps/active/web/dist`, not
    `.next`) + production `node_modules` + workspace package sources needed
    at runtime (drizzle schema + `src/db/migrations` must be in the image so
    `pnpm run db:migrate` works post-deploy)
  - Document the in-image web app dir (e.g. `/app/apps/active/web`) — the
    deploy's migration one-off container needs it
- [ ] Write root `.dockerignore` (`node_modules`, `dist`, `.next`, `.git`,
  `internal-docs`, `**/__tests__`, etc.) — keep the context small
- [ ] Add `just` recipe(s) in the acrm justfile, e.g.
  `docker-build-push-acrm` (and a `-force`/`--check` variant if convenient):
  `docker buildx build --platform linux/amd64 -t
  "${REGISTRY:-100.90.22.85:5000}/localnet-ai-acrm-web:latest" --push .`
- [ ] Verify `docker build` (or `buildx`) succeeds locally from a clean
  context; verify the image starts (`docker run --rm -e PORT=3000 -e
  DATABASE_URL=…` smoke check that `next start` binds 3000)
- [ ] Push to the registry; verify `curl -sf
  http://100.90.22.85:5000/v2/localnet-ai-acrm-web/manifests/latest`
- [ ] Optional: add `GET /api/health` route returning 200 JSON (nice-to-have;
  `/` already returns 200 and is used as the health probe)

## Relevant Files

- `~/p/gh/levonk/acrm/Dockerfile` (new)
- `~/p/gh/levonk/acrm/.dockerignore` (new)
- `~/p/gh/levonk/acrm/justfile` (append recipe)
- `~/p/gh/levonk/acrm/apps/active/web/Dockerfile` (superseded — either fix or
  delete; document the decision)
- `~/p/gh/levonk/acrm/apps/active/web/next.config.js` (`distDir: 'dist'`)
- `~/p/gh/levonk/acrm/apps/active/web/package.json` (drizzle-kit is a prod
  dep; `db:migrate` script)

## Acceptance Criteria

- Given a clean clone of the acrm repo, when `docker buildx build` runs from
  the repo root, then the build succeeds and produces a runnable image
- Given the image, when run with `DATABASE_URL` unset, then it starts
  `next start` on port 3000 (DB errors surface per-request, not at boot)
- Given the image and a reachable Postgres, when `docker run --rm <image>
  sh -c 'cd <web dir> && pnpm run db:migrate'` runs, then migrations apply
- Given the recipe, when run on the Mac, then the amd64 image is pushed to
  `100.90.22.85:5000/localnet-ai-acrm-web:latest`
- Given the Dockerfile, when inspected, then no secrets, no host IPs, and no
  hardcoded registry are baked in (registry is a recipe-time tag)

## Implementation Notes

- pnpm in Docker: `corepack enable pnpm` (existing Dockerfile pattern) or
  `npm i -g pnpm@<pinned>`; watch the `packageManager: pnpm@11.20.0` pin vs
  running pnpm 12.x warning (harmless per acrm AGENTS.md).
- `allowBuilds` in `pnpm-workspace.yaml` disables `better-sqlite3` — keep
  that behavior in the container install.
- Do NOT use `export const dynamic` workarounds; not needed — just build.
- Keep `apps/active/web/docker-compose.yml` as dev reference only (never
  deployed — infrahub rule).
- Option B packaging path chosen — see
  `internal-docs/research/service/acrm/packaging-analysis.md`. A follow-up
  may extend `scripts/build-and-push-images.sh` for external contexts; this
  story does not depend on it.

## Definition of Done

- Image builds from repo root and pushes to the local registry
- `next start` serves `/` (200) inside the container
- `pnpm run db:migrate` works inside the image against an external
  `DATABASE_URL`
- Recipe documented in acrm justfile; nothing committed to infrahub
