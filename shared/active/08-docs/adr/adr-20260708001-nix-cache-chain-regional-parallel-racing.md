# ADR-20260708001: Nix Cache Chain — Regional Multi-Layer with Parallel Racing

## Status
Accepted

## Context

The existing Nix cache strategy documented in `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md` describes a sequential "waterfall" of caches:

```
Harmonia (priority 30) → ncps (priority 40) → Attic (priority 50) → Garnix (priority 60) → nixos.org (priority 80)
```

Research conducted in July 2026 revealed that this approach is **outdated** for two reasons:

1. **Nix's substituter model is fundamentally sequential** — it walks caches in priority order, one at a time. A miss on the first cache adds full round-trip latency before even trying the second. The waterfall tries to work around this with priorities, but the core problem remains.

2. **New proxy tools solve this by racing all upstreams in parallel** — tools like [ncro](https://github.com/feel-co/ncro) query all upstream caches simultaneously and pick the fastest response, with EMA latency learning to optimize future requests.

### Tool Landscape (July 2026)

| Tool | Status | Role |
|------|--------|------|
| **Harmonia** v3.1.0 | Actively maintained, major improvements (removed nix-daemon, reads SQLite directly, 49% latency reduction) | Serve local /nix/store — still the gold standard for this |
| **Attic** | Maintained but still labeled "early prototype", 171 open issues | S3-backed multi-tenant cloud cache |
| **ncps** v0.9.4 | Active but carries production warnings | Local NAR caching proxy (bandwidth savings for LAN) |
| **ncro** | New (May 2026), stable, no production warnings | Parallel racing proxy — races all upstreams, EMA latency learning, streams NARs without storing |
| **Cachix** | Commercial, actively enhanced | Hosted binary cache (optional upstream) |

### Key Insight

ncps and ncro serve **complementary** purposes:
- **ncps** caches NARs locally → saves bandwidth for LAN clients
- **ncro** races upstreams in parallel → minimizes latency on cache misses

Used together (ncps as front door, ncro behind it), you get both bandwidth savings AND parallel racing.

## Decision

Implement a **regional multi-layer cache chain** with parallel racing:

### Architecture

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

### Components

1. **Harmonia** on every Nix-running machine (127.0.0.1, reads /nix/store:ro)
   - 5 machines: lzkmbp2016, lzkmbp2018, dtop202311, oci-cloud-server, isolation-vm
   - kckinai excluded (not running Nix)

2. **ncps** on 2 regional hubs (caches NARs for bandwidth savings)
   - dtop202311 (LAN region) — serves Macs + Windows
   - oci-cloud-server (Cloud region) — serves OCI + isolation-vm

3. **ncro** on 2 regional hubs (behind ncps, races all upstreams in parallel)
   - Co-located with ncps on dtop202311 and oci-cloud-server
   - Races: all 5 Harmonia instances + Attic + cache.nixos.org + optional Cachix

4. **Attic** on oci-cloud-server (cloud binary cache)
   - Serves as both an ncro upstream and a push target for CI builds

### Why This Replaces the Waterfall

| Aspect | Old Waterfall | New Chain |
|--------|--------------|-----------|
| Upstream queries | Sequential (one at a time) | Parallel (ncro races all) |
| Latency learning | None (static priorities) | EMA tracking (ncro learns fastest) |
| NAR caching | ncps only | ncps (front) + ncro streams on miss |
| Regional awareness | Single ncps | Two regional ncps+ncro pairs |
| Failure handling | Fall through sequentially | Parallel race + fallback cache |

## Consequences

### Positive
1. **Faster misses**: ncro races all upstreams in parallel instead of walking sequentially
2. **Bandwidth savings**: ncps caches NARs locally for LAN clients
3. **Latency optimization**: ncro learns which cache is fastest via EMA tracking
4. **Regional resilience**: Two independent ncps+ncro pairs — LAN works even if OCI is down
5. **Local-first**: Harmonia on every machine means local store hits are instant
6. **Observability**: ncro exposes Prometheus metrics + /health endpoint; ncps has OpenTelemetry

### Negative
1. **More services to manage**: 4 service types (Harmonia, ncps, ncro, Attic) across multiple machines
2. **ncro has no Docker image**: Must build from source (Nix flake or cargo build)
3. **ncro not in nixpkgs**: Must use flake input or manual build
4. **Two ncro instances to keep in sync**: Upstream list must be updated when machines change
5. **ncps production warnings**: Still carries early-development warnings despite active maintenance

### Risks
1. **ncro immaturity** (created May 2026): New project with 116 stars
   - **Mitigation**: Simple architecture (~3000 lines Rust), stateless data path, no production warnings, stable design
2. **ncps data consistency**: Early development warnings about data consistency
   - **Mitigation**: Use released versions only (never main branch), regular backups
3. **macOS OrbStack /nix/store bind mount**: May behave differently from Linux Docker
   - **Mitigation**: Test on one Mac first before deploying to both
4. **Complexity**: 4 Ansible roles, 5 target machines, 2 architectures (Linux Docker + macOS OrbStack)
   - **Mitigation**: Follow existing role patterns, infrastructure variables for all config

## Implementation Plan

### Phase 1: Build Images
- [ ] Build Harmonia container image (Nix flake), push to local registry
- [ ] Build ncro container image (Nix flake or cargo build), push to local registry
- [ ] Build Attic container image (Nix flake), push to local registry
- [ ] ncps: use existing Docker Hub image (source: pull)

### Phase 2: Infrastructure Variables
- [ ] Add port variables to shared + levonk infrastructure files
- [ ] Add storage paths for ncps NAR cache, Attic data, ncro SQLite
- [ ] Add Tailscale IPs for ncro upstream configuration

### Phase 3: Vault Secrets
- [ ] Add Harmonia signing key
- [ ] Add Attic HS256 secret + DB password
- [ ] Add Cachix auth token (optional)

### Phase 4: Ansible Roles
- [ ] Create `nix-harmonia` role
- [ ] Create `nix-ncps` role
- [ ] Create `nix-ncro` role
- [ ] Create `nix-attic` role

### Phase 5: Playbook + Inventory
- [ ] Create `nix-cache.yml` playbook
- [ ] Add inventory groups (nix_harmonia_hosts, nix_ncps_hosts, nix_ncro_hosts, nix_attic_hosts)

### Phase 6: Deploy + Verify
- [ ] Deploy to all 5 machines
- [ ] Verify health endpoints
- [ ] Configure nix.conf substituters
- [ ] End-to-end test with real nix builds

## ADR Compliance

This ADR follows infrahub architectural invariants:
- **shared/ is client-agnostic**: Roles and schemas in shared/, values in levonk/
- **community.docker modules**: All containers deployed via Ansible, never docker compose
- **Infrastructure variables**: All ports/IPs/domains use `infra_` naming convention
- **Vault for secrets**: Signing keys and tokens in client vault, never in shared/
- **Build before deploy**: Container images built on control machine, pushed to registry

## References

- [Harmonia](https://github.com/nix-community/harmonia) — local /nix/store server
- [ncps](https://github.com/kalbasit/ncps) — NAR caching proxy
- [ncro](https://github.com/feel-co/ncro) — parallel racing proxy
- [Attic](https://github.com/zhaofengli/attic) — multi-tenant binary cache
- [Cachix](https://www.cachix.org/) — hosted binary cache (optional)
- Previous strategy: `shared/active/03-container/internal-docs/requirements/nix/nix-package-store.md` (superseded)
- PRD: `internal-docs/feature/2026/07/nix-cache-chain/feat-202607081745-nix-cache-chain.md`
- Research: `internal-docs/research/service/nix-cache-chain/tool-comparison.md`
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- ADR-20260625001: Infrastructure Consolidation Strategy

## Revision History
- 2026-07-08: Initial ADR creation — Nix cache chain with parallel racing accepted, superseding waterfall strategy in nix-package-store.md
