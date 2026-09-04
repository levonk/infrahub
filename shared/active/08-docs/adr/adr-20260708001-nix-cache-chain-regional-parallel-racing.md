---
modeline: "vim: set ft=markdown:"
title: "ADR: Nix Cache Chain — Regional Multi-Layer with Parallel Racing"
adr-id: "adr-202607081745"
slug: "nix-cache-chain-regional-parallel-racing"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md"
synopsis: "Replace the sequential waterfall Nix cache strategy with a regional multi-layer chain using ncro for parallel upstream racing and ncps for local NAR caching."
author: "https://github.com/levonk"
date-created: "2026-07-08"
date-updated: "2026-09-04"
date-review: "2027-01-08"
date-triggers: ["2026-10-08"]
version: "0.1.0"
status: "accepted"
aliases: ["ADR-20260708001"]
tags: [doc/architecture/adr, nix, cache, harmonia, ncps, ncro, attic]
supersedes: ["nix-package-store-waterfall"]
superseded-by: []
related-to: ["hybrid-sensitive-information-storage", "infrastructure-consolidation", "macos-system-config-nix-darwin"]
scope:
  impact-scope: [lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm, nix-conf, ansible-roles]
  excluded-scope: [kckinai, mac-mini, nix-snapshotter, garnix, cachix-deployment]
---

> **Note**: This ADR references client-specific hostnames (e.g. `lzkmbp2016`, `lzkmbp2018`) for historical context. These hosts are specific to the levonk client. Current host configs live in `levonk/active/02-config/nix/darwin/`.

# Decision Record: Nix Cache Chain — Regional Multi-Layer with Parallel Racing

**Filename:** `adr-202607081745-nix-cache-chain-regional-parallel-racing.md`

- belongs in `shared/active/08-docs/adr/` (existing repo convention)

---

## Context

The existing Nix cache strategy documented in `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md` describes a sequential "waterfall" of caches: Harmonia (priority 30) → ncps (priority 40) → Attic (priority 50) → Garnix (priority 60) → nixos.org (priority 80).

Research conducted in July 2026 (see `internal-docs/research/service/nix-cache-chain/tool-comparison.md`) revealed that this approach is outdated for two reasons. First, Nix's substituter model is fundamentally sequential — it walks caches in priority order, one at a time, so a miss on the first cache adds full round-trip latency before even trying the second. The waterfall tries to work around this with priorities, but the core problem remains. Second, new proxy tools like [ncro](https://github.com/manic-systems/ncro) solve this by racing all upstream caches simultaneously and picking the fastest response, with EMA latency learning to optimize future requests.

The tool landscape as of July 2026: Harmonia v3.1.0 is still the gold standard for serving local /nix/store (major improvements — removed nix-daemon dependency, reads SQLite directly, 49% latency reduction). Attic is maintained but still labeled "early prototype" with 171 open issues. ncps v0.9.4 is active but carries production warnings. ncro is new (May 2026) but stable with no production warnings — it races all upstreams in parallel with EMA latency learning and streams NARs without storing them.

The key insight is that ncps and ncro serve complementary purposes: ncps caches NARs locally (saves bandwidth for LAN clients), while ncro races upstreams in parallel (minimizes latency on cache misses). Used together with ncps as the front door and ncro behind it, you get both bandwidth savings and parallel racing.

## Constraints

- All container deployment must use Ansible `community.docker` modules — never docker compose, never systemd (AGENTS.md invariants)
- All ports, IPs, and domains must be infrastructure variables — never hardcoded (ADR-20260625001)
- `shared/` directory must be client-agnostic — no client-specific values (ADR-20260624001)
- Secrets must be in client vault (`levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`)
- ncro has no Docker image — must build from source (Nix flake or cargo build)
- ncro is not in nixpkgs — must use flake input or manual build
- macOS machines use OrbStack for containers (not Docker Desktop)
- isolation-vm is behind SSH proxy through oci-cloud-server

## Decision

Implement a regional multi-layer cache chain with parallel racing: local Harmonia on every Nix machine, regional ncps+ncro pairs for NAR caching and parallel upstream racing, and Attic on OCI as the cloud binary cache.

## Rationale

The sequential waterfall adds latency on every miss because Nix walks substituters one at a time. ncro eliminates this by racing all upstreams in parallel and learning which is fastest via EMA latency tracking. However, ncro doesn't cache NARs — it streams them — so repeated downloads always hit upstream. ncps complements ncro by caching NARs locally for LAN bandwidth savings. Placing ncps as the front door (clients point to ncps) with ncro behind it (ncps queries ncro on miss, ncro races all upstreams, returns NAR to ncps which caches it) gives both parallel racing and local NAR caching.

Two regional ncps+ncro pairs (LAN on dtop202311, Cloud on oci-cloud-server) provide resilience — each region works independently even if the other is unreachable. Harmonia on every machine ensures local /nix/store hits are instant (sub-millisecond).

## Technical Approach

```
Every Nix machine nix.conf:
  priority 10: http://127.0.0.1:<port>         (local Harmonia)
  priority 20: http://<regional-ncps>:<port>   (regional ncps)

REGION 1 (LAN): dtop202311 hosts ncps + ncro
  ncps (front, caches NARs) → ncro (races upstreams in parallel)
  ncro upstreams: all Harmonia everywhere + Attic + cache.nixos.org + Cachix?

REGION 2 (Cloud): oci-cloud-server hosts ncps + ncro + Attic
  ncps (front, caches NARs) → ncro (races upstreams in parallel)
  ncro upstreams: all Harmonia everywhere + Attic (local) + cache.nixos.org + Cachix?
```

Components:
1. **Harmonia** on all 5 Nix-running machines (127.0.0.1, reads /nix/store:ro): lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm. kckinai excluded (not running Nix).
2. **ncps** on 2 regional hubs (caches NARs): dtop202311 (LAN), oci-cloud-server (Cloud).
3. **ncro** on 2 regional hubs (behind ncps, races all upstreams): co-located with ncps. Races all 5 Harmonia instances + Attic + cache.nixos.org + optional Cachix.
4. **Attic** on oci-cloud-server (cloud binary cache): serves as ncro upstream and push target for CI builds.

Four Ansible roles will be created in `shared/active/02-config/ansible/roles/`: `nix-harmonia`, `nix-ncps`, `nix-ncro`, `nix-attic`. All use `community.docker.docker_container`. Full implementation details in the PRD: `internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md`.

## Affected Components

- **Machines**: lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm
- **Ansible roles**: 4 new roles (nix-harmonia, nix-ncps, nix-ncro, nix-attic)
- **Infrastructure variables**: ports, storage paths, Tailscale IPs for ncro upstream config
- **Vault secrets**: Harmonia signing key, Attic HS256 secret, optional Cachix token
- **nix.conf**: all 5 machines' substituter configuration
- **nix-darwin**: `shared/active/02-config/nix/darwin/modules/nix/cache.nix` (TODO comment will be resolved)
- **Container images**: Harmonia + Attic built from Nix flakes, ncro built from source, ncps pulled from Docker Hub
- **Existing docs**: `nix-package-store.md` (superseded), `localnet-nix.md` (container analysis)

## Consequences

### Negative

- More services to manage: 4 service types across 5 machines (Harmonia everywhere, ncps+ncro on 2 hubs, Attic on 1)
- ncro has no Docker image — must build from source and maintain a container image build pipeline
- ncro is not in nixpkgs — must use flake input or manual build, increasing coupling to the ncro repo
- Two ncro instances must have their upstream lists kept in sync when machines are added or removed
- ncps still carries early-development production warnings despite active maintenance

### Positive

- Faster misses: ncro races all upstreams in parallel instead of walking sequentially
- Bandwidth savings: ncps caches NARs locally for LAN clients
- Latency optimization: ncro learns which cache is fastest via EMA tracking (α=0.3)
- Regional resilience: two independent ncps+ncro pairs — LAN works even if OCI is down
- Local-first: Harmonia on every machine means local store hits are instant
- Observability: ncro exposes Prometheus metrics + /health endpoint; ncps has OpenTelemetry

### Neutral

- ncro's stateless data path (no NAR storage) eliminates cache invalidation complexity but means repeated downloads always hit upstream — this is acceptable because ncps handles caching
- The architecture requires Tailscale to be operational on all machines for cross-machine Harmonia access — this is already a dependency of the existing infrastructure

## Alternatives Considered

- **Waterfall (status quo)** — Sequential substituter priorities. Pro: simple, one ncps. Con: sequential latency on every miss, no latency learning, single point of failure.
- **ncro only (no ncps)** — Parallel racing without NAR caching. Pro: simplest, fastest for first fetch. Con: no bandwidth savings (always hits upstream), Harmonia alone provides local store serving but no LAN-level caching.
- **ncps only (no ncro)** — NAR caching with sequential upstream queries. Pro: simpler than two services, caches NARs. Con: sequential upstream queries on miss (the original waterfall problem), no latency learning.
- **selector4nix** — Similar to ncro but with nix-darwin module. Pro: native macOS integration. Con: no metrics endpoint, no Docker image, lowest community adoption (34 stars), per-host focused (not central proxy).

## Rollout / Migration

1. **Build images**: Harmonia + Attic from Nix flakes, ncro from source, ncps from Docker Hub. Push to local registry on OCI.
2. **Infrastructure variables**: Add port, storage, and network variables to shared + levonk infrastructure files.
3. **Vault secrets**: User adds Harmonia signing key + Attic secrets to vault.
4. **Ansible roles**: Create 4 roles following existing patterns (e.g., `agentmemory`, `cloudflare-ddns`).
5. **Playbook + inventory**: Create `nix-cache.yml` playbook, add inventory groups.
6. **Deploy + verify**: Deploy to all 5 machines, verify health endpoints, configure nix.conf substituters.
7. **End-to-end test**: Verify cache chain works for real nix builds.

Rollback: If the new chain causes issues, revert nix.conf to point directly at cache.nixos.org. The containers can be stopped without affecting the Nix store. The old waterfall config in `nix-package-store.md` is preserved (marked superseded) for reference.

## To Investigate

- Should Cachix be included as an ncro upstream? Requires Cachix account and auth token in vault.
- Does ncro provide a Nix flake for container building, or do we need to write a Dockerfile / Nix flake ourselves?
- macOS OrbStack /nix/store bind mount behavior — does it differ from Linux Docker? Test on one Mac first.
- ncps production readiness — monitor for data consistency issues during the rollout period.

## Validation

- All 5 machines have working local Harmonia (verified by `curl http://127.0.0.1:5000/nix-cache-info`)
- Both regional ncps+ncro pairs are operational (verified by health endpoints: ncps `/healthz`, ncro `/health`)
- Attic on OCI is operational (verified by API endpoint)
- `nix path-info --substituters 'http://127.0.0.1:5000' <store-path>` resolves from local Harmonia on at least one machine
- `nix build` operations on any machine use the cache chain (verified by observing ncro metrics for race wins)
- No hardcoded IPs or ports in any role/playbook/template (grep verification)
- No secrets in shared/ directory (grep verification)

## Review Schedule

- **3 months** (2026-10-08): Check ncro stability, ncps production warning status, and whether any new tools have emerged
- **6 months** (2027-01-08): Full review — is the architecture performing well? Should Cachix be added? Should the Mac mini be added now that it's deployable?

## Notes

- The previous waterfall strategy is preserved in `nix-package-store.md` (marked superseded with a banner pointing to this ADR) for historical reference.
- The `cache.nix` nix-darwin module has a TODO comment referencing this ADR for when local Harmonia is deployed.
- Implementation details belong in the PRD: `internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md`

## Supplement: Garnix Shutdown Validation of Excluded-Scope Decision

**Date:** 2026-09-04

Garnix (hosted Nix CI + binary cache) ceased hosted operations on **July 15 2026** following its acquisition by Shopify. The team open-sourced the codebase at [github.com/garnix-io/garnix-ci](https://github.com/garnix-io/garnix-ci) and invited community members to run their own instances. Source: [LavX news article](https://news.lavx.hu/article/garnix-announces-shutdown-and-open-source-release-after-joining-shopify).

This event validates the `excluded-scope` decision in this ADR's frontmatter, which listed `garnix` as explicitly excluded from the cache chain architecture. The analysis at the time of the ADR (July 2026) avoided relying on a hosted third-party Nix CI — the exact failure mode that materialized.

### Analysis: Self-Hosted Garnix vs. Current Cache Chain

The open-source release does not warrant revisiting the excluded-scope decision, for three reasons:

1. **Different problem domain.** Garnix is a *CI builder* (builds flake outputs on push, sets GitHub commit checks, serves a binary cache as a byproduct). This ADR's cache chain is a *cache acceleration layer* (parallel racing via ncro, local NAR caching via ncps, local store serving via Harmonia, cloud binary cache via Attic). They are complementary at best, not substitutive. CI needs are already covered by GitHub Actions pushing to Attic, per ADR-20260709001's three-branch decision tree.

2. **Significant complexity increase.** Self-hosting Garnix requires: QEMU VMs via `nixos-compose`, a GitHub App registration, a backend service, a frontend (npm), a database, and admin tooling. The current cache chain is four lightweight containerized services deployed via Ansible `community.docker` modules. Self-hosting Garnix would add operational burden without replacing any existing component.

3. **Incomplete architecture coverage.** The fleet (per ADR-20260709001) spans four architectures. Garnix's coverage:

   | Architecture | Garnix support | Fleet need |
   |---|---|---|
   | x86_64-linux | Native (Hetzner x86) | dtop202311 WSL2, isolation-vm |
   | aarch64-darwin | Native (M1 server, added May 2022) | lzkmbp2018 (Apple Silicon Mac) |
   | aarch64-linux | Emulation only (binfmt/QEMU), reverted/limited due to resource costs | OCI cloud server (aarch64) |
   | x86_64-darwin | **Not supported** — [issue #16](https://github.com/garnix-io/issues/issues/16) closed with "not planning to do this" | lzkmbp2016 (Intel Mac, OpenCore) |

   Garnix covers 2 of 4 fleet architectures natively. It cannot build for x86_64-darwin at all, and aarch64-linux is emulation-only — the same QEMU emulation that ADR-20260709001 explicitly rejected due to Rust/mold segfaults and 10-24x slowdown.

### Conclusion

No preference changes warranted. The Garnix shutdown is recorded here as a validation data point for the 3-month review (2026-10-08). The `excluded-scope` decision stands.

## Supplement: Nix-Sidecar Shared Store and Architecture Specificity

**Date:** 2026-09-04

During deployment preparation, the question arose of whether the nix-sidecar shared `/nix/store` volume can be shared across all fleet architectures (mac x86_64, mac aarch64, linux x86_64, linux aarch64).

### Decision: Per-Architecture Nix-Sidecar, Not Cross-Arch

The `/nix/store` is **architecture-specific**. A store path built for `x86_64-linux` cannot be used by `aarch64-linux` and vice versa. A single nix-sidecar shared store volume cannot serve multiple architectures. However, this is not a problem for the cache chain because each host runs its own nix-sidecar (or native Nix installation) with its own arch-appropriate store:

| Host | Arch | Nix store source | Harmonia access |
|------|------|-----------------|-----------------|
| dtop202311 (nl) | x86_64-linux | nix-sidecar Docker volume | `nix_harmonia_nix_store_volume` (shared sidecar volume) |
| oci-cloud-server (cno) | aarch64-linux | Native host installation | Bind-mount `/nix/store` from host |
| lzkmbp2016 (Mac) | x86_64-darwin | Native host installation | (future: local Harmonia) |
| lzkmbp2018 (Mac) | x86_64-darwin | Native host installation | (future: local Harmonia) |

### Which Cache Chain Containers Need /nix/store at Runtime?

Only **Harmonia** needs `/nix/store` at runtime — it serves the local store over HTTP to Nix clients. The other two containers do not:

- **ncro**: Stateless Rust binary. No `/nix/store` dependency at runtime. Built as a Docker image from a Nix flake per-arch (`x86_64-linux`, `aarch64-linux`).
- **ncps**: Go binary from upstream multi-arch image (`ghcr.io/kalbasit/ncps:main`). No `/nix/store` dependency at runtime.

### Nix-Sidecar Sharing Within an Architecture

On dtop202311 (nl), the nix-sidecar provides a shared `/nix/store` Docker volume. Harmonia mounts this volume read-only (`-v {{ nix_harmonia_nix_store_volume }}:/shared-nix:ro`) and serves it. Other containers that need Nix at runtime on the same host can also mount this volume, avoiding redundant downloads — but only within the same architecture.

### Cross-Architecture Cache Sharing

Cross-architecture sharing happens at the **NAR level** via ncps/ncro, not at the store level. When an x86_64-linux client requests a store path, ncro races upstreams (including the local Harmonia) for the x86_64-linux NAR. An aarch64-linux client does the same for aarch64-linux NARs. The ncps cache stores NARs keyed by store path hash, which includes the architecture derivation. So a single ncps instance can serve NARs for multiple architectures — but the `/nix/store` itself (served by Harmonia) is always arch-specific.

### Implication for macOS Laptops

The levonk Mac laptops (lzkmbp2016, lzkmbp2018) are both `x86_64-darwin`. They do not run nix-sidecar (Nix is installed natively via Determinate Nix). When on the LAN, they can use the nl ncps cache (`cache.nl.levonk.com`) as a substituter for `x86_64-darwin` NARs. The ncps cache will fetch from upstreams on miss and cache the NAR for future use. This is configured in the client-specific nix-darwin configuration, not in the shared `cache.nix` module.

## References

- [Harmonia](https://github.com/nix-community/harmonia) — local /nix/store server
- [ncps](https://github.com/kalbasit/ncps) — NAR caching proxy
- [ncro](https://github.com/manic-systems/ncro) — parallel racing proxy
- [Attic](https://github.com/zhaofengli/attic) — multi-tenant binary cache
- [Cachix](https://www.cachix.org/) — hosted binary cache (optional upstream)
- Previous strategy (superseded): `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md`
- PRD: `internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md`
- Research: `internal-docs/research/service/nix-cache-chain/tool-comparison.md`
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- ADR-20260625001: Infrastructure Consolidation Strategy
- ADR-202607070001: macOS System Config via nix-darwin (references `cache.nix` module)

<!-- vim: set ft=markdown: -->
