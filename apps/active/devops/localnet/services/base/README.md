# Base Images for LocalNet

Secure Debian and Alpine base images derived from the hardened `dhi.io` OS series. Every service image in LocalNet is built on top of these layers so the same security posture, user model, and filesystem layout propagate across the stack.

It also includes `nix-sidecar` image for managing the Nix store, caching and nix configuration.

Based off of standard debian slim is `base-debnix` this is Debian with the nix package manager loaded which uses the volumes that `nix-sidecar` manages.

Based off of `base-debnix` we have `base-dev` which is a package for a developer to use for development. `base-dev` also mounts the volumes from `nix-sidecar` so that the developer can use the nix package manager.

## ⭐ Highlights

- ☑️ **Immutable baseline**: Debian (Bookworm) and Alpine (3.19) variants published as `base-debian` and `base-alpine` images.
- 🔐 **Security-first defaults**: Non-root `appuser`, no SUID/SGID binaries (beyond what is explicitly allowed), and aggressive filesystem cleanup.
- 🧰 **Ready for derived builds**: Package managers remain available so higher-level images can install only what they need.
- 📦 **Composable tooling**: A dedicated Makefile, docker-compose file, and quality gate script mirror the standards from the docker-compose copier boilerplate.

## ☑️ Base OS Targets

| Image         | Upstream Tag                 | Purpose                                   |
| ------------- | ---------------------------- | ----------------------------------------- |
| `base-alpine` | `dhi.io/alpine-base:latest`  | Ultra-small footprint, security-centric   |
| `base-debian` | `dhi.io/debian-base:bookworm`| Debian compatibility + richer ecosystem   |

Each image lives under `services/base/<variant>/docker/Dockerfile.<variant>` and keeps the UID/GID mapping identical (`1001:1001`) so derived services can swap OSes without permission drift.

## 🛠️ Usage

```bash
# build both base images
make build

# rebuild with fresh upstream layers
make build FORCE_PULL=1

# run the base compose file (useful for quick validation)
make up
make logs
make down

# lint Dockerfiles + compose definitions
make lint
```

The Makefile automatically loads `../../.env` when present so shared variables (e.g., registry URLs) flow in without duplication.

## 🔬 Quality & Security Checks

Run all static checks exactly like the docker-compose boilerplate:

```bash
make lint
```

`scripts/run-quality-checks.sh` executes the following with containerized tooling:

1. `docker compose config` sanity validation.
2. `yamllint` for `docker-compose.base.yml`.
3. `markdownlint` for this README.
4. `hadolint` for both Debian and Alpine Dockerfiles.
5. `checkov` + `trivy config` scans for IaC and Docker misconfigurations.

## 🔐 Hardening Primer

- Removes `.pyc`, `.pyo`, and `__pycache__` artifacts to avoid stale bytecode.
- Drops SUID/SGID bits (except explicitly allowed binaries) to prevent privilege escalation.
- Locks down `/etc/service`, `/healthcheck`, and `/tmp` permissions.
- Ships with `su-exec` (Alpine) so derived services can continue privilege dropping if they briefly elevate to root at build time.

See `.windsurf/rules/dockerfile-best-practices.md` for the broader policy referenced by every LocalNet Dockerfile.

## 📂 Layout

```
services/base/
├── README.md
├── Makefile
├── docker-compose.base.yml
├── scripts/
│   └── run-quality-checks.sh
├── base-alpine/
│   └── docker/Dockerfile.base-alpine
└── base-debian/
    └── docker/Dockerfile.base-debian
```

## 📌 Next Steps

1. Add CI wiring (GitHub workflow) that runs `scripts/run-quality-checks.sh` on pull requests touching this directory.
2. Publish `base-*` images to your registry of choice once upstream `dhi.io` releases are vetted.
3. Keep Debian/Alpine package pins aligned with the security cadence documented in `VALIDATION_REPORT.md`.
