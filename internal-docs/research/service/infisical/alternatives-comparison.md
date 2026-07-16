# Secrets Management Platforms: Alternatives Comparison

> **Research date:** July 2026
> **Context:** Homelab / small-business deployment on a Linux/ARM64 OCI cloud server (Oracle Cloud), using Docker + Docker Compose + Ansible. Already using Ansible Vault for some secrets. Limited maintenance time.
> **Primary candidate:** [Infisical](https://github.com/infisical/infisical)

---

## TL;DR Recommendation

**Infisical is the best fit** for this homelab/small-business context. It is open-source (MIT core), self-hostable, ships official multi-arch Docker images (including `linux/arm64`), has a polished web UI + CLI + API, supports GitOps/CI-CD injection, Kubernetes operator, RBAC, SSO, and dynamic secrets — all with a moderate resource footprint and low-to-moderate maintenance burden.

**Runner-up:** **SOPS + age** as a complementary file-based layer for GitOps-stored secrets (no server to run, zero maintenance, works alongside Infisical or Ansible Vault).

**Avoid for this context:** HashiCorp Vault (too complex, BSL license, heavy), Conjur (niche, small community, Ruby-based, low momentum), Doppler/Akeyless (SaaS-only / not truly self-hostable for homelab).

See the [full recommendation](#recommendation) section below for details.

---

## Feature Matrix

| Dimension | Infisical | Vault | Doppler | Akeyless | SOPS + age | Vaultwarden | Conjur |
|-----------|-----------|-------|---------|----------|------------|-------------|--------|
| **Self-hostable?** | Yes | Yes | Enterprise on-prem only (not homelab) | Hybrid gateway only (secrets stay in SaaS) | N/A (file-based, no server) | Yes | Yes |
| **Open source?** | Yes (MIT core) | Source-available (BSL 1.1) | No (proprietary SaaS) | No (proprietary SaaS) | Yes (MPL-2.0) | Yes (AGPL-3.0) | Yes (LGPL-3.0) |
| **License** | MIT (core); proprietary `ee/` dir for enterprise features | BSL 1.1 (since Aug 2023; was MPL-2.0) | Proprietary / closed | Proprietary / closed | MPL-2.0 | AGPL-3.0 | LGPL-3.0 (server); Apache-2.0 (clients) |
| **ARM64 support** | Yes — official `linux/arm64` Docker images | Yes — official `linux/arm64` Docker images | N/A (SaaS) | N/A (SaaS; gateway is x86-centric) | Yes — `linux/arm64` binaries + Docker images | Yes — official `linux/arm64` Docker images | Partial — community/older ARM64 images exist (`cyberark/conjur:1.21.1-arm64`); not consistently multi-arch on latest |
| **Docker images available** | Yes (`infisical/infisical`, multi-arch) | Yes (`hashicorp/vault`, multi-arch) | N/A | Gateway image only (limited) | Yes (`getsops/sops`, multi-arch) | Yes (`vaultwarden/server`, multi-arch) | Yes (`cyberark/conjur`) |
| **Complexity (1-5, 5=hardest)** | 2 | 5 | 1 (SaaS) | 1 (SaaS) | 2 | 1 | 4 |
| **Secret rotation** | Yes (native, automatic) | Yes (via secret engines) | Yes (Team plan+) | Yes (native) | No (manual / external) | No | Limited (via scripts) |
| **Dynamic secrets** | Yes (DB, AWS, CI/CD providers) | Yes (extensive — DB, cloud, PKI, SSH, etc.) | Yes (Enterprise only) | Yes (native) | No | No | Limited |
| **CLI tool** | Yes (`infisical`) | Yes (`vault`) | Yes (`doppler`) | Yes (`akeyless`) | Yes (`sops`) | Yes (`bw` — Bitwarden CLI) | Yes (`conjur`) |
| **API** | Yes (REST + GraphQL) | Yes (REST + gRPC) | Yes (REST) | Yes (REST) | No (no server) | Yes (Bitwarden API-compatible) | Yes (REST) |
| **Web UI** | Yes (modern, React) | Yes (Vault Enterprise / open-source UI is basic) | Yes (SaaS dashboard) | Yes (SaaS dashboard) | No | Yes (Bitwarden web vault) | Limited (basic admin UI) |
| **GitOps / CI-CD integration** | Yes (CLI injection, GitHub/GitLab actions, native sync) | Yes (via external tooling) | Yes (CI/CD integrations) | Yes (CI/CD integrations) | Yes (core use case — encrypted files in git) | No | Limited |
| **Kubernetes integration** | Yes (native operator + External Secrets Operator support) | Yes (Vault Agent injector, CSI, ESO) | Yes (ESO) | Yes (ESO) | Yes (via ESO / Helm secrets) | No | Yes (via sidecar / ESO) |
| **Docker/Docker Compose integration** | Yes (CLI injection, env-file export) | Yes (but requires agent sidecar) | Yes (CLI injection) | Yes (gateway) | Yes (decrypt to env-file at deploy) | No (not designed for app secrets) | Limited |
| **Audit logging** | Yes (built-in audit logs) | Yes (comprehensive audit devices) | Yes (activity logs) | Yes | No (git history only) | Limited | Yes |
| **RBAC** | Yes (project + environment scoped) | Yes (policies, fine-grained) | Yes (Team plan+) | Yes | No (relies on git/KMS access) | Limited (org policies) | Yes (role-based) |
| **SSO/SAML** | Yes (SAML, OIDC, Google, Okta, Azure AD) | Yes (auth methods: OIDC, SAML, LDAP) | Yes (Team plan+) | Yes | No | Limited (via Bitwarden SSO) | Yes (LDAP, SAML) |
| **Community size (GitHub stars)** | ~27.8K | ~35.8K | N/A (proprietary) | N/A (proprietary) | ~22.3K | ~63.7K | ~940 |
| **Maintenance burden (1-5, 5=highest)** | 2 | 4 | 0 (SaaS) | 0 (SaaS) | 1 | 1 | 3 |
| **Resource footprint** | Medium (app + Postgres + Redis; ~4GB RAM min) | Heavy (storage backend, HA, monitoring) | Zero (SaaS) | Zero (SaaS) | Negligible (CLI binary only) | Light (single Rust binary + SQLite/DB; ~256MB RAM) | Medium (Ruby app + Postgres) |

> **Note on star counts:** Figures are approximate as of July 2026, sourced from GitHub. Vaultwarden's high star count reflects its popularity as a personal/team password manager, not as an app-secrets platform.

---

## Detailed Profiles

### 1. Infisical (infisical/infisical)

- **GitHub:** https://github.com/infisical/infisical — ~27.8K stars, ~2K forks, 240+ contributors
- **Latest release:** v0.162.x (very active — 542+ releases)
- **License:** MIT (core codebase); `ee/` directory contains enterprise features under a proprietary Infisical license
- **Architecture:** Node.js/TypeScript backend + React frontend; requires PostgreSQL + Redis
- **ARM64:** Official multi-arch Docker images (`linux/amd64` + `linux/arm64`) on Docker Hub (`infisical/infisical`)
- **Deployment:** Single Docker image + docker-compose with Postgres + Redis; official docker-compose.prod.yml provided
- **Minimum resources:** 2 CPU / 4GB RAM (recommended 4 CPU / 8GB)

**Strengths:**
- Modern, polished web UI — best-in-class for self-hosted
- First-class GitOps: CLI secret injection (`infisical run --`), GitHub/GitLab CI integrations, native secret sync to cloud providers
- Kubernetes operator (InfisicalSecret, InfisicalPushSecret, InfisicalDynamicSecret CRDs) + External Secrets Operator support
- Dynamic secrets (database, AWS, CI/CD tokens)
- Automatic secret rotation
- RBAC scoped to projects + environments
- SSO/SAML/OIDC support
- Secret scanning, PKI/certificate management
- Active development (multiple releases per week)
- MIT license for core features — genuinely open source

**Weaknesses:**
- Requires Postgres + Redis (3 containers minimum)
- Enterprise features (advanced RBAC, audit log streaming, approval workflows) are behind `ee/` license
- Relatively young project (2022) — fewer battle-tested production deployments than Vault
- Self-hosting means you own uptime, backups, and upgrades

**Maintainability score: 7/10** — Regular upgrades are straightforward (pull new image, run migrations), but you manage Postgres + Redis + the app. The upgrade tool helps plan version bumps.

---

### 2. HashiCorp Vault (hashicorp/vault)

- **GitHub:** https://github.com/hashicorp/vault — ~35.8K stars, ~4.7K forks, 390+ contributors
- **Latest release:** v2.0.x
- **License:** BSL 1.1 (Business Source License) since August 2023; was MPL-2.0 before. Now owned by IBM (acquired Feb 2025). **Not OSI-certified open source** — source-available with restrictions on competitive use.
- **Architecture:** Go binary; storage backends include Integrated Raft, Consul, file, DynamoDB, etc.
- **ARM64:** Official multi-arch Docker images (`linux/amd64` + `linux/arm64`) on Docker Hub (`hashicorp/vault`)
- **Deployment:** Single binary or Docker; can run in dev mode (file storage) or production (Raft/Consul)

**Strengths:**
- Industry standard — most mature, feature-complete secrets manager
- Extensive dynamic secret engines (DB, AWS, Azure, GCP, SSH, PKI, Kerberos, RabbitMQ, etc.)
- Comprehensive audit logging (multiple audit devices)
- Fine-grained policy-based RBAC (HCL policies)
- Rich auth methods (OIDC, SAML, LDAP, K8s, AWS IAM, AppRole, cert, etc.)
- Vault Agent injector for Kubernetes (auto-inject secrets into pods)
- Massive ecosystem, documentation, and community knowledge

**Weaknesses:**
- **BSL 1.1 license** — not truly open source; restrictions on commercial/competitive use. This is a significant concern for long-term sovereignty.
- **High complexity** — steep learning curve (HCL policies, mounts, paths, tokens, leases)
- **Heavy operational burden** — unsealing, HA setup, storage backend maintenance, token lifecycle management
- Open-source UI is basic; good UIs (Vault Enterprise) are paid
- Overkill for homelab/small-business — designed for enterprise scale
- IBM acquisition raises questions about future licensing and community engagement

**Maintainability score: 4/10** — Unseal keys management, storage backend maintenance, token TTL tuning, and policy management make this a high-maintenance choice. Dev mode is easy but not production-safe.

---

### 3. Doppler

- **Website:** https://www.doppler.com
- **Type:** SaaS-only (proprietary, closed-source)
- **Pricing:** Free (3 users) → Team ($21/user/mo) → Enterprise (custom). On-prem option is Enterprise-only.
- **License:** Proprietary / closed source

**Strengths:**
- Zero maintenance (fully managed SaaS)
- Excellent developer UX — CLI, dashboard, CI/CD integrations
- Flat per-seat pricing (unlimited secrets, service accounts)
- Secret referencing, config syncs, change requests
- Automatic secret rotation (Team plan+)

**Weaknesses:**
- **Not self-hostable** for homelab/small-business (on-prem is enterprise-only)
- **Not open source** — complete vendor lock-in
- Secrets leave your infrastructure (data sovereignty concern)
- Per-user pricing adds up for small teams
- No ARM64 relevance (it's SaaS)

**Maintainability score: 10/10 (for SaaS)** — but irrelevant since it doesn't meet the self-hosting requirement. Included for comparison only.

---

### 4. Akeyless

- **Website:** https://www.akeyless.io
- **Type:** SaaS with hybrid gateway (proprietary, closed-source)
- **Pricing:** Custom/enterprise-focused; usage-based
- **License:** Proprietary / closed source

**Strengths:**
- Zero-knowledge encryption (Distributed Fragments Cryptography — vendor never holds complete key)
- Hybrid model: on-prem gateway keeps secrets in your network while control plane is SaaS
- Dynamic secrets, rotation, ephemeral access
- SaaS means no infrastructure maintenance for the core platform

**Weaknesses:**
- **Not truly self-hostable** — gateway is a proxy, not a full platform; control plane is always SaaS
- **Not open source** — vendor lock-in
- Enterprise-focused pricing — not homelab-friendly
- Gateway images are x86-centric; ARM64 support is unclear/limited
- Complexity of hybrid architecture may be overkill for small deployments

**Maintainability score: 8/10 (for SaaS)** — but doesn't meet self-hosting/open-source requirements. The gateway adds some operational overhead.

---

### 5. SOPS + age (getsops/sops)

- **GitHub:** https://github.com/getsops/sops — ~22.3K stars, ~1K forks, 190+ contributors
- **Latest release:** v3.13.x
- **License:** MPL-2.0 (OSI-certified open source); CNCF Sandbox project
- **Architecture:** CLI tool — encrypts values in YAML/JSON/ENV/INI files; no server required
- **ARM64:** Yes — official `linux/arm64` binaries and Docker images (`getsops/sops`)
- **Encryption backends:** age (recommended), PGP, AWS KMS, GCP KMS, Azure Key Vault, HuaweiCloud KMS

**Strengths:**
- **Zero infrastructure** — no server, no database, no Redis; just a CLI binary
- **GitOps-native** — encrypted files live in git, version-controlled, reviewable in PRs
- **age encryption** — simple, modern, no configuration servers needed (just key pairs)
- **Negligible maintenance** — upgrade the binary, that's it
- **Tiny resource footprint** — runs anywhere, including ARM64
- Works perfectly with Ansible (decrypt files at deploy time)
- MPL-2.0 license — genuinely open source
- CNCF Sandbox project — vendor-neutral governance

**Weaknesses:**
- **No server/UI/API** — not a centralized secrets platform; file-based only
- **No dynamic secrets** — static encrypted values only
- **No automatic rotation** — must rotate manually or via external automation
- **No RBAC** — access control is via key management (who has the age private key)
- **No real-time secret distribution** — secrets are pulled from files, not pushed to apps
- **Key management burden** — managing age private keys securely is on you
- Not ideal for runtime secret injection into running containers (need a wrapper)

**Maintainability score: 9/10** — Almost zero maintenance. The only ongoing work is key rotation and ensuring private keys are backed up securely.

---

### 6. Vaultwarden (dani-garcia/vaultwarden)

- **GitHub:** https://github.com/dani-garcia/vaultwarden — ~63.7K stars, ~3K forks, 170+ contributors
- **Latest release:** v1.35.x
- **License:** AGPL-3.0 (OSI-certified open source)
- **Architecture:** Rust binary; uses SQLite (default), MySQL, or PostgreSQL
- **ARM64:** Yes — official multi-arch Docker images (`linux/arm64`) on Docker Hub (`vaultwarden/server`)
- **Deployment:** Single Docker container; SQLite backend needs no external DB

**Strengths:**
- **Extremely lightweight** — single Rust binary, ~256MB RAM, SQLite by default
- **Bitwarden-compatible** — works with all Bitwarden clients (desktop, mobile, browser, CLI)
- **Excellent for personal/team password management** — autofill, sharing, organizations
- **Very low maintenance** — update the container, done
- **ARM64 native** — runs perfectly on OCI ARM instances
- AGPL-3.0 — genuinely open source
- Huge community (highest star count of any tool in this list)

**Weaknesses:**
- **Not a secrets management platform** — it's a password manager; no dynamic secrets, no secret injection, no GitOps, no K8s operator
- **No app-secret injection** — can't feed secrets into running containers/CI-CD pipelines natively
- **No API for machine access** — Bitwarden CLI exists but is designed for human workflows, not service-to-service
- **No secret rotation** — manual password changes only
- **No RBAC beyond Bitwarden org policies** — not environment/project scoped
- Not designed for infrastructure/DevOps secrets workflows

**Maintainability score: 9/10** — Trivially easy to run. But it solves a different problem (personal/team passwords, not app/infra secrets).

---

### 7. Conjur (cyberark/conjur)

- **GitHub:** https://github.com/cyberark/conjur — ~940 stars, ~147 forks, 90+ contributors
- **Latest release:** v1.27.x
- **License:** LGPL-3.0 (server); Apache-2.0 (API clients)
- **Architecture:** Ruby (Rails) server + PostgreSQL
- **ARM64:** Partial — older tagged ARM64 images exist (`cyberark/conjur:1.21.1-arm64`); latest images are not consistently multi-arch
- **Deployment:** Docker Compose quickstart available (demo only); production setup is more involved

**Strengths:**
- Open source (LGPL-3.0)
- Enterprise-grade secrets management by CyberArk (major security vendor)
- Machine identity focused — designed for privileged user and machine secret access
- RBAC with policy-based access control (declarative YAML policies)
- REST API
- Audit logging

**Weaknesses:**
- **Very small community** — ~940 stars, low momentum compared to alternatives
- **Ruby-based** — heavier, slower development velocity
- **ARM64 support is inconsistent** — not reliably multi-arch on latest releases
- **Complex policy model** — steep learning curve for the declarative policy DSL
- **No modern web UI** — basic admin interface only
- **Limited GitOps/CI-CD integration** — not a first-class use case
- **No Kubernetes operator** — relies on sidecar/ESO integration
- **Niche positioning** — designed for enterprise privileged access, not homelab DevOps
- Quickstart Docker Compose is explicitly "demo only, not for production"

**Maintainability score: 4/10** — Complex policy management, Ruby/Postgres stack, inconsistent ARM64 support, and a small community make this hard to recommend for a homelab.

---

## Maintainability Scores Summary

| Tool | Score (1-10) | Rationale |
|------|:---:|-----------|
| **SOPS + age** | 9 | No server to maintain. Upgrade the binary. Manage age keys. |
| **Vaultwarden** | 9 | Single container, SQLite, trivial updates. But solves password management, not app secrets. |
| **Infisical** | 7 | Manage app + Postgres + Redis, but upgrades are smooth. Active project, good docs. |
| **Akeyless** | 8* | SaaS = zero maintenance, but gateway adds some ops. *Doesn't meet self-host requirement. |
| **Doppler** | 10* | Fully managed SaaS. *Doesn't meet self-host requirement. |
| **Vault** | 4 | Unseal keys, storage backend, HA, token lifecycle, policy management. Heavy. |
| **Conjur** | 4 | Complex policies, Ruby/Postgres stack, inconsistent ARM64, small community. |

---

## Coverage Map

| Use Case | Infisical | Vault | Doppler | Akeyless | SOPS+age | Vaultwarden | Conjur |
|----------|:---------:|:-----:|:-------:|:--------:|:--------:|:-----------:|:------:|
| **App secrets** (inject into running apps/containers) | ✅ | ✅ | ✅ | ✅ | ⚠️ (decrypt-at-deploy only) | ❌ | ✅ |
| **Infra secrets** (DB creds, API keys for services) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Personal/team passwords** (browser autofill, mobile) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **CI/CD secrets** (GitHub Actions, GitLab CI) | ✅ | ⚠️ (via tooling) | ✅ | ✅ | ✅ | ❌ | ⚠️ |
| **Kubernetes secrets** (operator/injection) | ✅ | ✅ | ✅ | ✅ | ✅ (via ESO) | ❌ | ✅ |
| **GitOps** (encrypted secrets in git repo) | ✅ (sync) | ⚠️ (via tooling) | ❌ | ❌ | ✅ (core use case) | ❌ | ❌ |
| **Dynamic secrets** (ephemeral DB/cloud creds) | ✅ | ✅ | ✅ (Enterprise) | ✅ | ❌ | ❌ | ⚠️ |
| **Secret rotation** (automatic) | ✅ | ✅ | ✅ (Team+) | ✅ | ❌ | ❌ | ⚠️ |
| **Certificate/PKI management** | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Ansible integration** | ✅ (CLI/API) | ✅ (lookup plugin) | ✅ (CLI) | ✅ (API) | ✅ (native fit) | ❌ | ⚠️ |

---

## Recommendation

### Given Constraints

| Constraint | Implication |
|-----------|-------------|
| **Homelab / small-business** | Need low complexity, low maintenance, reasonable resource footprint |
| **Linux/ARM64 OCI cloud server** | Must have native ARM64 Docker images (no emulation) |
| **Docker + Docker Compose + Ansible** | Must integrate with container workflows and Ansible playbooks |
| **Limited maintenance time** | Prefer tools that are easy to upgrade and don't require constant tuning |
| **Already using Ansible Vault** | New tool should complement, not necessarily replace, Ansible Vault |

### Primary Recommendation: Infisical

**Infisical is the best fit** for the following reasons:

1. **Self-hostable + open source (MIT):** Genuinely open source with no BSL restrictions. You own your data.
2. **ARM64 native:** Official multi-arch Docker images with `linux/arm64` support — runs natively on Oracle Cloud ARM instances.
3. **Docker Compose deployment:** Official `docker-compose.prod.yml` with Postgres + Redis. Well-documented, 3-container setup.
4. **Modern web UI:** Best-in-class self-hosted UI for managing secrets across projects and environments.
5. **CLI + API:** `infisical` CLI for CI/CD injection (`infisical run --`), REST API for automation and Ansible integration.
6. **GitOps native:** Secret sync to GitHub/GitLab, CI/CD integrations, encrypted secret export.
7. **Kubernetes ready:** Native operator + External Secrets Operator support (future-proof if K8s is adopted).
8. **Dynamic secrets + rotation:** Supports database, AWS, and CI/CD dynamic secrets with automatic rotation.
9. **RBAC + SSO:** Project/environment-scoped RBAC, SAML/OIDC SSO support.
10. **Active development:** 542+ releases, 240+ contributors, weekly updates — the project is thriving.
11. **Moderate footprint:** 4GB RAM minimum is feasible on an OCI Ampere A1 instance (which typically offers 24GB RAM on the free tier).

**How it fits with existing Ansible Vault:**
- Infisical becomes the **central secrets platform** for app/infra secrets that need runtime injection, rotation, and multi-environment management.
- Ansible Vault continues to handle **deployment-time secrets** (e.g., Infisical's own `ENCRYPTION_KEY`, `AUTH_SECRET`, DB passwords) — the bootstrap layer.
- Infisical CLI can be invoked from Ansible playbooks to pull secrets at runtime: `infisical secrets --plain --env=prod` piped into Ansible vars.
- Alternatively, use Infisical's API in Ansible `uri` tasks to fetch secrets dynamically.

### Complementary Recommendation: SOPS + age

**Add SOPS + age as a complementary GitOps layer:**

- Use SOPS for **secrets that belong in git** (e.g., encrypted Helm values, Ansible inventory files, Terraform variables).
- Use age (not PGP) for simplicity — a single key pair, no keyserver infrastructure.
- SOPS-encrypted files can be committed to git, reviewed in PRs, and decrypted at deploy time by Ansible (`sops --decrypt` or the Ansible `sops` lookup plugin).
- **Zero additional infrastructure** — just a binary on the Ansible control node.
- This fills the gap that Infisical doesn't cover as elegantly: version-controlled, reviewable secret files in git.

### Why Not the Others?

| Tool | Why not for this context |
|------|--------------------------|
| **Vault** | Too complex (unsealing, policies, token management), BSL license (not truly open source), heavy resource footprint, overkill for homelab. IBM acquisition adds uncertainty. |
| **Doppler** | Not self-hostable for homelab (on-prem is enterprise-only). Not open source. SaaS-only doesn't meet the requirement. |
| **Akeyless** | Not truly self-hostable (gateway only, control plane is SaaS). Not open source. Enterprise pricing. ARM64 unclear. |
| **Vaultwarden** | Excellent tool, but it's a **password manager**, not a secrets management platform. No app-secret injection, no dynamic secrets, no GitOps, no K8s integration. **Recommend running it alongside Infisical** for personal/team password management — they solve different problems. |
| **Conjur** | Small community (~940 stars), Ruby-based, complex policy DSL, inconsistent ARM64 support, no modern UI, niche enterprise positioning. Not worth the maintenance burden for a homelab. |

### Suggested Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     OCI ARM64 Server                         │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │
│  │  Infisical   │──▶│  PostgreSQL  │   │    Redis     │     │
│  │  (app)       │   │  (secrets DB)│   │  (cache/jobs)│     │
│  └──────┬───────┘   └──────────────┘   └──────────────┘     │
│         │                                                    │
│         │ API / CLI                                          │
│         ▼                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │
│  │  App containers (pull secrets via Infisical CLI/API) │     │
│  └──────────────┘   └──────────────┘   └──────────────┘     │
│                                                              │
│  ┌──────────────┐                                            │
│  │ Vaultwarden  │  (personal/team password manager —        │
│  │ (SQLite)     │   separate concern, optional)              │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Ansible Control Node (local)                    │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐                        │
│  │ Ansible Vault│   │  SOPS + age  │                        │
│  │ (bootstrap   │   │ (GitOps      │                        │
│  │  secrets)    │   │  encrypted   │                        │
│  │              │   │  files)      │                        │
│  └──────┬───────┘   └──────┬───────┘                        │
│         │                  │                                 │
│         └──────┬───────────┘                                │
│                ▼                                             │
│         ansible-playbook → Docker API → Infisical            │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Checklist for Infisical on ARM64 OCI

1. **Provision:** OCI Ampere A1 Compute (4 OCPU / 24GB RAM free tier is sufficient)
2. **Docker:** Install Docker Engine + Docker Compose v2 (ARM64 native)
3. **Infisical:** Pull `infisical/infisical:<version>` (multi-arch, ARM64 supported)
4. **Compose:** Use official `docker-compose.prod.yml` (Infisical + Postgres + Redis)
5. **Bootstrap secrets:** Store `ENCRYPTION_KEY`, `AUTH_SECRET`, `DB_CONNECTION_URI` in Ansible Vault
6. **Reverse proxy:** Caddy/Traefik in front of Infisical for TLS
7. **Backup:** Schedule `pg_dump` of the Postgres container
8. **Monitoring:** Optional — Infisical exposes health endpoints
9. **Upgrades:** Pull new image tag, `docker compose up -d`, Infisical runs migrations automatically

---

## Sources

- Infisical: https://github.com/Infisical/infisical (accessed Jul 2026)
- Infisical docs (self-hosting, K8s operator): https://infisical.com/docs/
- HashiCorp Vault: https://github.com/hashicorp/vault (accessed Jul 2026)
- HashiCorp BSL announcement: https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license
- HashiCorp license FAQ: https://www.hashicorp.com/en/license-faq
- Doppler pricing: https://www.doppler.com/pricing
- Doppler on-prem: https://www.doppler.com/doppler-on-prem
- Akeyless pricing: https://www.akeyless.io/pricing/
- SOPS: https://github.com/getsops/sops (accessed Jul 2026)
- SOPS docs: https://getsops.io/docs/
- Vaultwarden: https://github.com/dani-garcia/vaultwarden (accessed Jul 2026)
- Bitwarden server license: https://github.com/bitwarden/server/blob/main/LICENSE_FAQ.md
- Conjur: https://github.com/cyberark/conjur (accessed Jul 2026)
- Conjur license: https://github.com/cyberark/conjur/blob/master/LICENSE.md
- External Secrets Operator (Infisical provider): https://external-secrets.io/main/provider/infisical/
- Infisical Docker Hub: https://hub.docker.com/r/infisical/infisical/tags
- Vault Docker Hub: https://hub.docker.com/r/hashicorp/vault/tags
