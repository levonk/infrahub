# Packaging Analysis — Graduating Side Projects into Infrahub Deployment

Question under analysis:

> What's a good way to smooth the transition from side projects to the
> infrahub disciplined deployment system? Is Verdaccio
> (`npmjs.nl.levonk.com` private npm registry) the right bridge?

**Short answer: no.** Infrahub's deployment artifact is a **Docker image in
the local OCI registry** (`100.90.22.85:5000`), not an npm package. Verdaccio
is the right tool for *library reuse* and *npm caching during builds*, but it
sits one layer below the deployment boundary — an app is not deployable in
infrahub until it is a container image. The smoothest bridge is therefore a
**repo-local Dockerfile + a build-and-push recipe in the side project**, with
infrahub owning only role/vars/DNS/Traefik. Details below.

## What infrahub actually consumes

The deployment boundary (verified across `artifact-verdaccio`,
`search-hister`, `tools-stirling-pdf`, `ai-n8n`, `ai-paperclip`):

1. **Artifact**: a Docker image — upstream (`verdaccio/verdaccio`,
   `postgres:17-alpine`, `ghcr.io/asciimoo/hister`) or locally built and
   pushed to `{{ infra_registry }}` (`100.90.22.85:5000`, on the OCI host,
   HTTP-over-Tailscale, no auth).
2. **Delivery**: the target pulls the image from the registry
   (`docker pull` over `DOCKER_HOST: ssh://` for Windows targets;
   `community.docker.docker_image source: pull` on Linux).
3. **Everything else** — ports, domains, volumes, networks, secrets,
   Traefik routes, DNS records, service-catalog metadata — is Ansible-side
   configuration, independent of how the image was produced.

Nothing in that chain consumes npm packages. `npmjs.nl.levonk.com` never
appears in any Dockerfile under `shared/active/03-container/services/`
(verified by grep) — it is used for publishing/consuming `@levonk`-style
libraries and as a caching uplink, not as a deployment artifact store.

## What Verdaccio is actually good for here

| Use | Applies to ACRM? | Notes |
|-----|------------------|-------|
| Publish `@acrm/*` workspace libs for reuse by *other* repos | Later, maybe | Only needed if a second repo imports `@acrm/core` etc. — pnpm `workspace:*` deps are resolved inside the monorepo at build time and do not need a registry |
| npm cache/uplink during Docker builds | Optional optimization | `pnpm install` inside the Dockerfile could point at verdaccio (`--registry https://npmjs.nl.levonk.com`) to cut build time and work offline; adds a runtime dependency on the nl registry being up during builds |
| Private packages that must not hit npmjs.org | N/A today | ACRM ships an app image, not published packages |
| Deployment artifact for infrahub | **No** | Wrong artifact type |

## Options compared

### (a) Dockerfile clones GitHub during build (paperclip pattern)

`shared/active/03-container/services/ai-codeassist/paperclip/Dockerfile`
does `git clone https://github.com/paperclipai/paperclip.git` inside the
build.

- ✅ Context stays tiny and inside `services/`; slots directly into
  `scripts/build-and-push-images.sh` with zero script changes.
- ❌ **Fails for private repos**: anonymous clone of `levonk/acrm` returns
  404. Fixing it means baking an SSH deploy key or GitHub token into the
  build (`--secret`/mount or ARG), which puts a credential into image
  layers/history unless done with buildkit secrets — doable but fiddly, and
  it makes the infrahub repo depend on repo-level Git credentials.
- ❌ Builds a moving ref (`--branch master`) — poor reproducibility for a
  private app under active development; you want "deploy the commit I just
  tested," not "deploy whatever HEAD is when the build runs."

### (b) Dockerfile lives in the side-project repo; build+push from there

Dockerfile at the acrm repo root (required anyway — pnpm workspaces need the
monorepo root as build context to resolve `workspace:*` deps), plus a
`just docker-build-push` recipe in acrm's justfile pushing
`100.90.22.85:5000/localnet-ai-acrm-web:latest`.

- ✅ Correct build context for pnpm/Nx monorepos (the existing
  `apps/active/web/Dockerfile` is broken precisely because it assumes a
  single-package context — `COPY package.json pnpm-lock.yaml*` can't
  resolve `workspace:*`).
- ✅ The image build lives next to the code it builds — versioned together,
  PR'd together; infrahub stays app-agnostic.
- ✅ No credentials in the build: the developer's checkout IS the source.
- ✅ Reproducible: builds exactly the working tree you tested.
- ❌ Two-command deploy (`just docker-build-push` in acrm, then
  `just ansible-deploy-acrm` in infrahub) — mitigated by documenting it, or
  by having the infrahub deploy recipe call the acrm recipe (acceptable
  coupling, same machine).
- ❌ Duplicates a small amount of build plumbing per side project
  (registry URL, ctxhash caching, platform flags live in
  `build-and-push-images.sh`).

### (c) Vendor the source into infrahub

Copy/subtree acrm source under `shared/active/03-container/services/ai/acrm/`.

- ✅ Fits `build-and-push-images.sh` unchanged.
- ❌ Duplicated source of truth; drifts immediately. Violates the
  private-repo boundary — vendoring a private repo into infrahub's shared/
  tree copies private code into a different repo's history.

### (d) Publish `@acrm/*` packages to Verdaccio; Dockerfile installs from it

Publish each workspace package, then the Dockerfile (living under
`services/`) does `pnpm install @acrm/web` from verdaccio.

- ✅ Matches "real" package-registry workflows; enables cross-repo reuse.
- ❌ Massive overhead for an app (not a library): needs versioning,
  `pnpm publish` of every workspace package, a build/order pipeline, and a
  Dockerfile that reassembles a Next.js app from tarballs — Next standalone
  builds don't work that way; you'd rebuild inside the container anyway,
  so you've added a publish step for zero benefit.
- ❌ Adds verdaccio auth/uptime as a hard build dependency.
- ❌ Still doesn't remove the Dockerfile — it just moves the source of
  `node_modules`. The deploy artifact is still the image.

## Recommendation

**Option (b)** — repo-local Dockerfile + build/push recipe in the side
project — is the smoothest repeatable path, with **option (a)'s plumbing
kept available** via an optional follow-up: extend
`scripts/build-and-push-images.sh` to accept an external context
(e.g. `name|dockerfile|abs:/path/to/repo` entries or a
`EXTERNAL_SERVICES` map), so `just docker-build-push` in infrahub can still
drive side-project builds when wanted. Do (b) now; adopt (a-extension) only
if/when the second or third private app graduates and the duplicated recipe
is felt.

Verdaccio's role in the graduation story is orthogonal and optional: use it
when a side project needs to **share libraries** with other repos, or as an
npm cache to make monorepo Docker builds faster/network-independent. Do not
route app deployment through it.

## Side-project graduation checklist

For any future private side project entering infrahub deployment:

1. **Containerize in the side repo** — a working root-context Dockerfile +
   `.dockerignore`; verify `docker build` locally. Fix the app's container
   story *before* touching infrahub. (ACRM: `apps/active/web/Dockerfile` is
   single-context and broken — needs a monorepo-aware root Dockerfile.)
2. **Build & push recipe in the side repo** — `just docker-build-push`
   pushing `{infra_registry}/localnet-{category}-{svc}:latest`; document the
   platform(s) of the target region (`nl` = amd64, `cno` = arm64).
3. **Decide the region & host** — which inventory group; whether
   `community.docker` works there (Linux) or the ssh-tunneled CLI pattern is
   required (Windows).
4. **Allocate infra vars** — `infra_port_*` (conflict-scan both ports.yml
   files), `infra_domain_*`, `infra_hostname_*`, `infra_storage_*`,
   `infra_network_*` in shared schemas + levonk overrides; `infra_value_*`
   fallbacks in `values.yml`.
5. **Secrets** — enumerate `vault_*` vars; prepare the vault-handoff docker
   command for the user; reference with `| default('')` + assert non-empty.
6. **Role** — `roles/{prefix}-{svc}/` with per-OS dispatch; Windows path =
   render locally → `docker cp`/env → `docker run` via `DOCKER_HOST: ssh://`.
7. **Edge** — Traefik template + enable flag; decide the auth split
   (SSO-gated UI vs token-gated API — see stirling/verdaccio precedents);
   DNS records in `configure-cloudflare-dns.yml` (+ playbook Phase 0).
8. **Playbook + just recipes + devbox.json** — deploy/validate entries.
9. **Catalog** — `services.yml` entries (with `source_repo`), regenerate
   `SERVICES.md` + `levonk/SERVICES.md`.
10. **Backup & monitoring posture** — postgres ⇒ sidecar or documented
    deferral; health endpoint for the catalog/monitoring fields.
