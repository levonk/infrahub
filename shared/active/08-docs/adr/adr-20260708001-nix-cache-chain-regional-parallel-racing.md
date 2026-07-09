---
modeline: "vim: set ft=markdown:"
title: "ADR: Nix Cache Chain — Regional Multi-Layer with Parallel Racing"
adr-id: "adr-202607081745"
slug: "nix-cache-chain-regional-parallel-racing"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md"
synopsis: "Replace the sequential waterfall Nix cache strategy with a regional multi-layer chain using ncro for parallel upstream racing and ncps for local NAR caching."
author: "https://github.com/levonk"
date-created: "2026-07-08"
date-updated: "2026-07-08"
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

# Decision Record: Nix Cache Chain — Regional Multi-Layer with Parallel Racing

**Filename:** `adr-202607081745-nix-cache-chain-regional-parallel-racing.md`

- belongs in `shared/active/08-docs/adr/` (existing repo convention)

---

## Context

The existing Nix cache strategy documented in `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md` describes a sequential "waterfall" of caches: Harmonia (priority 30) → ncps (priority 40) → Attic (priority 50) → Garnix (priority 60) → nixos.org (priority 80).

Research conducted in July 2026 (see `internal-docs/research/service/nix-cache-chain/tool-comparison.md`) revealed that this approach is outdated for two reasons. First, Nix's substituter model is fundamentally sequential — it walks caches in priority order, one at a time, so a miss on the first cache adds full round-trip latency before even trying the second. The waterfall tries to work around this with priorities, but the core problem remains. Second, new proxy tools like [ncro](https://github.com/feel-co/ncro) solve this by racing all upstream caches simultaneously and picking the fastest response, with EMA latency learning to optimize future requests.

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

## References

- [Harmonia](https://github.com/nix-community/harmonia) — local /nix/store server
- [ncps](https://github.com/kalbasit/ncps) — NAR caching proxy
- [ncro](https://github.com/feel-co/ncro) — parallel racing proxy
- [Attic](https://github.com/zhaofengli/attic) — multi-tenant binary cache
- [Cachix](https://www.cachix.org/) — hosted binary cache (optional upstream)
- Previous strategy (superseded): `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md`
- PRD: `internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md`
- Research: `internal-docs/research/service/nix-cache-chain/tool-comparison.md`
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- ADR-20260625001: Infrastructure Consolidation Strategy
- ADR-202607070001: macOS System Config via nix-darwin (references `cache.nix` module)

<!-- vim: set ft=markdown: -->
