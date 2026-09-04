# Pipeline Documentation

Consolidated documentation for all traffic chains in the LocalNet infrastructure. Each pipeline has its own subdirectory with the main chain doc, supporting diagrams, and requirements.

## Pipelines

### [AI Pipeline](ai/PIPELINE-AI.md)

The AI agent request pipeline — from development environment to LLM providers and tool APIs.

**Three request paths:**
- **LLM requests**: Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet
- **Tool calls**: Pi → treg (credential relay) → Iron-Proxy → Internet *(Phase 6)*
- **Agent memory**: Pi → paxm (local SQLite) ← sync → agentmemory (remote MCP)

**Two tiers:**
- **Development environment** (local/homelab container): herdr (terminal runtime) → acryl (persistent dev env) → pi (coding harness) + paxm (local memory) + Omnigent (orchestrator)
- **Remote server** (OCI cloud): agentmemory + treg + LiteLLM → Headroom → OmniRoute → Iron-Proxy

**Request origin peers**: Buzz (Nostr relay), Paperclip (agent orchestration)

**Observability**: Langfuse (parallel sink, traces from LiteLLM)

**Phases:**
- Phase 1 (current MVP): LiteLLM + Headroom + OmniRoute + Iron-Proxy + Langfuse
- Phase 2 (deferred): Forge (tool-call repair)
- Phase 3 (deferred): NordVPN (privacy egress)
- Phase 4 (deferred): AI Dashboard Proxy 1/2 + DB (analytics collectors)
- Phase 5 (deferred): Standalone Privacy Orchestrator
- Phase 6 (deferred): treg Tool Registry (non-LLM tool call key management)

**Key docs:**
- [AI Pipeline](ai/PIPELINE-AI.md) — main pipeline configuration
- [Archon vs Omnigent Evaluation](ai/2026-07-07-archon-vs-omnigent-evaluation.md) — orchestrator comparison

### [Web Proxy Chain](web/complete-web-proxy-chain.md)

The general-purpose web proxy chain for all client devices on the LAN. Handles HTTPS decryption, content filtering, caching, and egress routing.

```
Client → nftables → MITM (decrypt) → Privoxy (filter) → Varnish (cache) → Gost (egress) → Direct/Tor/WARP → Internet
```

**Key docs:**
- [Web Proxy Chain](web/complete-web-proxy-chain.md) — chain notes and design lineage
- [Web Proxy Chain Diagram](web/complete-web-proxy-chain.mmd) — Mermaid diagram
- [Caching Strategy](web/requirements/caching-strategy.md) — Varnish vs Squid decision
- [Egress Routing](web/requirements/egress-routing.md) — Gost egress multiplexer config
- [MITM CA Distribution](web/requirements/mitm-ca-distribution.md) — CA certificate strategy
- [Cross-Cluster Web Proxy](web/requirements/cross-cluster-web-proxy.md) — cross-cluster topology

### [DNS Chain](dns/complete-dns-chain.md)

The DNS resolution chain with DNSSEC validation, multi-tier fallback, and privacy tiers (ODoH, DNSCrypt, DoH, DoT, Tor, plaintext).

```
Client → nftables → dnsdist → CoreDNS → Unbound (DNSSEC validate) → Tier 1-12 fallback → Internet
```

**Key docs:**
- [DNS Chain](dns/complete-dns-chain.md) — chain notes and design lineage
- [DNS Chain Diagram](dns/complete-dns-chain.mmd) — Mermaid diagram
- [DNSSEC Gap and Unbound Fix](dns/requirements/dnssec-gap-and-unbound-fix.md) — DNSSEC validation gap analysis
- [Cross-Cluster DNS Failover](dns/requirements/cross-cluster-dns-failover.md) — cross-cluster failover options
- [CoreDNS vs Unbound](dns/requirements/coredns-vs-unbound.md) — original comparison
- [AdGuard vs Pi-hole](dns/requirements/adguard-vs-pihole.md) — DNS filtering comparison

### [NTP Chain](ntp/ntp-chain.md)

The NTP time synchronization chain with NTS (Network Time Security), leap smearing, and multi-tier fallback.

```
Client → nftables → chronyd (NTS + leap smear) → Google NTP / NIST / Pool / Cloudflare / Apple / Microsoft
```

**Key docs:**
- [NTP Chain](ntp/ntp-chain.md) — NTP flow diagrams and upstream selection strategy

### [Overall Architecture](overall-architecture.md)

The overall system architecture showing all four chains (DNS, NTP, Web Proxy, AI Pipeline) as peers, with nftables TPROXY as the host-layer interception point and WireGuard for VPN access.

## Cross-Pipeline Relationships

- **AI Pipeline ↔ Web Proxy Chain**: Agent requests (LLM and tool calls) currently egress through Iron-Proxy directly. The web proxy chain is a separate egress system for general LAN traffic. The relationship is **undecided** — see [AI Pipeline → Web Proxy Chain Relationship](ai/PIPELINE-AI.md#web-proxy-chain-relationship-undecided) for the two options.
- **Web Proxy Chain ↔ DNS Chain**: All proxy services use the LocalNet DNS chain for DNS resolution, benefiting from the same filtering, caching, and security policies. The Tor SOCKS5 proxy at `172.26.255.70:9050` is shared between both chains.
- **DNS Chain ↔ NTP Chain**: Both use nftables TPROXY for transparent interception at the host layer. Both have cross-cluster topology (local LAN + cloud OCI).
- **All chains**: All use the same nftables TPROXY infrastructure for transparent interception, the same Tailscale trust boundary (internal traffic bypasses the chains), and the same logging/monitoring stack.

## Directory Structure

```
shared/docs/pipelines/
├── README.md                          ← this index
├── overall-architecture.md            ← system overview showing all four chains
├── ai/
│   ├── PIPELINE-AI.md                 ← AI pipeline (LLM + tool calls + agent memory)
│   └── 2026-07-07-archon-vs-omnigent-evaluation.md
├── web/
│   ├── complete-web-proxy-chain.md    ← web proxy chain notes
│   ├── complete-web-proxy-chain.mmd   ← Mermaid diagram
│   └── requirements/
│       ├── caching-strategy.md
│       ├── egress-routing.md
│       ├── mitm-ca-distribution.md
│       └── cross-cluster-web-proxy.md
├── dns/
│   ├── complete-dns-chain.md          ← DNS chain notes
│   ├── complete-dns-chain.mmd         ← Mermaid diagram
│   └── requirements/
│       ├── dnssec-gap-and-unbound-fix.md
│       ├── cross-cluster-dns-failover.md
│       ├── coredns-vs-unbound.md
│       └── adguard-vs-pihole.md
└── ntp/
    └── ntp-chain.md                   ← NTP flow diagrams
```

## Origin Paths (before consolidation)

These docs were previously scattered across different directories with different naming conventions:

| Chain | Old path | New path |
|---|---|---|
| AI Pipeline | `shared/docs/PIPELINE-AI.md` | `shared/docs/pipelines/ai/PIPELINE-AI.md` |
| Web Proxy Chain | `shared/active/03-container/internal-docs/diagrams/proxy/complete-web-proxy-chain.notes.md` | `shared/docs/pipelines/web/complete-web-proxy-chain.md` |
| DNS Chain | `shared/active/03-container/internal-docs/diagrams/dns/complete-dns-chain.notes.md` | `shared/docs/pipelines/dns/complete-dns-chain.md` |
| NTP Chain | `shared/active/03-container/internal-docs/diagrams/03-ntp-flow.md` | `shared/docs/pipelines/ntp/ntp-chain.md` |
| Overall Architecture | `shared/active/03-container/internal-docs/diagrams/01-overall-architecture.md` | `shared/docs/pipelines/overall-architecture.md` |
