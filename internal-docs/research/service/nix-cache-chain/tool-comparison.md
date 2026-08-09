# Nix Cache Tool Comparison (2026)

## Overview

Research conducted to determine the current state of Nix binary cache tools and whether the existing "waterfall" strategy (Harmonia → ncps → Attic → Garnix → nixos.org) documented in `nix-package-store.md` is still the gold standard.

## Key Finding: The Waterfall Is Outdated

Nix's substituter model walks caches **sequentially** in priority order. The waterfall strategy tries to work around this with priorities, but the fundamental approach is flawed — a miss on the first cache adds latency before even trying the second. Modern proxy tools (ncro, selector4nix) solve this by **racing all caches in parallel**.

## Tool Status Summary

### Still Gold Standard

| Tool | Status | Notes |
|---|---|---|
| **Harmonia** v3.1.0 | Actively maintained, major improvements | Removed nix-daemon dependency, reads SQLite directly, 49% latency reduction, Prometheus metrics. **Top choice for serving /nix/store** |
| **Attic** | Maintained but still labeled "early prototype", 171 open issues | S3-backed multi-tenant cache. Functional but maintenance backlog |
| **Cachix** | Commercial, actively enhanced | Still gold standard for hosted |

### New Tools to Consider

| Tool | Purpose | Key Innovation |
|---|---|---|
| **ncro** | Cache route optimizer | Races all upstreams in parallel, EMA latency learning, zero NAR storage (streams) |
| **selector4nix** | Parallel substituter proxy | Similar to ncro, has nix-darwin module, per-host focused |
| **nix-serve-ng** | Drop-in nix-serve replacement | 1.5-32x faster, Arista Networks maintained |
| **FlakeHub Cache** | Identity-aware zero-config cache | Determinate Systems, Cachix competitor |

### ncps Status

NCPS v0.9.4 is actively maintained but carries explicit production warnings. Still the best tool for **local NAR caching** (bandwidth savings for LAN). Sequential upstream queries (doesn't race).

## Feature Matrix: Proxy Comparison

| Feature | ncps | ncro | selector4nix |
|---|---|---|---|
| License | MIT | EUPL 1.2 | GPL-3.0 |
| Stars | 311 | 116 | 34 |
| In nixpkgs | Yes | No | No |
| Docker image | Yes | No | No |
| NixOS module | Yes | Yes (repo) | Yes (repo) |
| nix-darwin module | No | No | Yes |
| Language | Go | Rust | Rust |
| NAR storage | Stores locally | Streams only | Streams only |
| Bandwidth savings | Yes (caches NARs) | No | No |
| Parallel racing | No (sequential) | Yes (FuturesUnordered) | Yes |
| Latency learning | No | Yes (EMA α=0.3) | Yes |
| Config complexity | High (DB, Redis, S3) | Low (TOML) | Low (NixOS module) |
| Metrics | OTel + Prometheus | Prometheus (7 metrics) | None |
| Health endpoint | /healthz | /health JSON | None |
| Production warnings | Early stage warnings | Stable, no warnings | Stable, no warnings |

## Decision: ncps + ncro (Both)

The correct architecture uses **both** ncps and ncro:
- **ncps** as front door (caches NARs for LAN bandwidth savings)
- **ncro** behind ncps (races all upstreams in parallel for fastest miss resolution)

This gives both parallel racing AND local NAR caching. See the PRD for the full architecture.

## References

- [Attic](https://github.com/zhaofengli/attic)
- [Harmonia](https://github.com/nix-community/harmonia)
- [NCPS](https://github.com/kalbasit/ncps)
- [ncro](https://github.com/manic-systems/ncro)
- [selector4nix](https://github.com/StarryReverie/selector4nix)
- [nix-serve-ng](https://github.com/aristanetworks/nix-serve-ng)
- [Cachix](https://www.cachix.org/)
- [FlakeHub Cache](https://flakehub.com/)
