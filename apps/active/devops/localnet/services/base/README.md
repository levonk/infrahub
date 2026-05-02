# Base Images for LocalNet

Secure Debian and Alpine base images derived from the hardened `dhi.io` OS series. Every service image in LocalNet is built on top of these layers so the same security posture, user model, and filesystem layout propagate across the stack.

## Container Hierarchy

```
Base Images (OS Foundation)
├── base-alpine  → dhi.io/alpine-base:latest  (lightweight, minimal footprint)
├── base-debian  → dhi.io/debian-base:trixie  (richer ecosystem)
└── base-kali    → kalilinux/kali-rolling      (security testing)
    ↑
Nix-Enabled Variants
├── base-nix     → Pure Nix + Nix package manager
├── base-debnix  → Debian + Nix package manager
└── base-kalinix → Kali + Nix package manager
    ↑
Working Environment
└── base-dev     → Developer workspace (inherits base-kalinix)

Sidecar
├── nix-sidecar  → Manages Nix store and caching
└── base-sidecar → Base for other sidecars (inheritance only)
```

### Base Images (OS Foundation)

These wrap third-party hardened images to allow easy swapping:

| Image         | Upstream                     | Purpose                                           |
| ------------- | ---------------------------- | ------------------------------------------------- |
| `base-alpine` | `dhi.io/alpine-base:latest`  | Ultra-small footprint, lightweight services     |
| `base-debian` | `dhi.io/debian-base:trixie` | Debian compatibility + richer ecosystem           |
| `base-kali`   | `kalilinux/kali-rolling`     | Security testing with Kali tools pre-installed    |

### Nix-Enabled Variants

These variants add the Nix package manager on top of OS foundation:

| Image           | Inherits From | Purpose                                         |
| --------------- | ------------- | ------------------------------------------------|
| `base-nix`      | `nixpkgs/nix` | Pure Nix environment, minimal base            |
| `base-debnix`   | `debian`      | Debian + Nix for Debian compatibility           |
| `base-kalinix`  | `base-kali`   | Kali + Nix for security testing with Nix        |

### Sidecar Services

| Image           | Purpose                                         |
| --------------- | ------------------------------------------------|
| `nix-sidecar`   | **CRITICAL**: Manages Nix store, cache, and config volumes. All Nix services depend on this. |
| `base-sidecar`  | Base image for other sidecars to inherit from.  |

### Working Environment

| Image      | Inherits From   | Purpose                                         |
| ---------- | --------------- | ------------------------------------------------|
| `base-dev` | `base-kalinix`  | Developer workspace with Nix + all dev tools.   |

## ⭐ Highlights

- ☑️ **Immutable baseline**: Debian (Bookworm) and Alpine (3.19) variants published as `base-debian` and `base-alpine` images.
- 🔐 **Security-first defaults**: Non-root `appuser`, no SUID/SGID binaries (beyond what is explicitly allowed), and aggressive filesystem cleanup.
- 🧰 **Ready for derived builds**: Package managers remain available so higher-level images can install only what they need.
- 📦 **Composable tooling**: A dedicated Makefile, docker-compose file, and quality gate script mirror the standards from the docker-compose copier boilerplate.

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
│   ├── Dockerfile.base-alpine
│   └── entrypoint.sh
├── base-debian/
│   ├── Dockerfile.base-debian
│   └── entrypoint.sh
├── base-kali/
│   ├── Dockerfile.base-kali
│   └── assets/
├── base-kalinix/
│   ├── Dockerfile.base-kalinix
│   └── assets/
├── base-debnix/
│   ├── Dockerfile.base-debnix
│   └── assets/
├── base-nix/
│   ├── Dockerfile.base-nix
│   └── assets/
├── base-sidecar/
│   ├── Dockerfile.base-sidecar
│   └── assets/
├── base-dev/
│   ├── Dockerfile.base-dev
│   ├── README.md
│   └── assets/
└── nix-sidecar/
    ├── Dockerfile.nix-sidecar
    ├── assets/
    └── tests/

## 📌 Next Steps

1. Add CI wiring (GitHub workflow) that runs `scripts/run-quality-checks.sh` on pull requests touching this directory.
2. Publish `base-*` images to your registry of choice once upstream `dhi.io` releases are vetted.
3. Keep Debian/Alpine package pins aligned with the security cadence documented in `VALIDATION_REPORT.md`.
