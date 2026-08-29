---
modeline: "vim: set ft=markdown:"
title: "ADR: Pipeline Observability Strategy — Topology-Aware Monitoring with Alert Inhibition"
adr-id: "202608270001"
slug: "pipeline-observability-strategy"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md"
synopsis: "Topology-aware monitoring across AI, DNS, Web, and VPN/egress pipelines with Alertmanager inhibition to surface root-cause failures and suppress downstream alert storms. Per-client monitoring instances. Includes synthetic OpenAI-compatible API probes for AI pipeline end-to-end validation."
author: "https://github.com/levonk"
date-created: "2026-08-27"
date-updated: "2026-08-27"
date-review: "2026-12-27"
date-triggers: ["2026-08-27"]
version: "1.0.0"
status: "proposed"
aliases: []
tags: [doc/architecture/adr, observability, monitoring, alerting, alertmanager, prometheus, loki, grafana]
supersedes: []
superseded-by: []
related-to:
  - "adr-20260624001-hybrid-sensitive-information-storage"
  - "adr-20260625001-infrastructure-consolidation"
  - "adr-20260625001-multi-exit-node-architecture"
scope:
  impact-scope: [monitoring, alerting, observability, prometheus, grafana, loki, alertmanager, uptime-kuma, synthetic-probes, ai-pipeline, dns-pipeline, web-proxy-pipeline, vpn-egress-pipeline]
  excluded-scope: [ai-pipeline-tracing-langfuse, security-audit-playbooks]
  client-scope: [levonk]
---

# Decision Record: Pipeline Observability Strategy — Topology-Aware Monitoring with Alert Inhibition

- belongs in `shared/active/08-docs/adr/adr-*.md`

---

## Context

The infrahub project operates four interdependent service pipelines per client:

1. **AI Pipeline** — `Omnigent → Pi → LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN`
2. **DNS Pipeline** — `AdGuard → dnsdist → CoreDNS → DNSCrypt/Tor → upstream resolvers` (with cross-cluster failover)
3. **Web Proxy Pipeline** — `MITM → Privoxy → Varnish → Gost → Tor` (local + cloud clusters, no cross-cluster failover)
4. **VPN/Egress Pipeline** — `NordVPN / WireGuard / Tor / host-direct exit nodes` (shared by all other pipelines)

These pipelines have **explicit upstream/downstream dependencies**. When an upstream component fails, every downstream component also fails, producing a flood of alerts that obscures the root cause. Example documented in `requirements/proxy/cross-cluster-web-proxy.md`: if the DNS chain fails, the web proxy chain also fails to resolve domains — but today there is no monitoring layer that correlates these two failure events.

### Current State

| Concern | Tool | Status |
|---|---|---|
| AI pipeline tracing | Langfuse | **Deployed** (LiteLLM → Langfuse integration) |
| Per-service metrics endpoints | Traefik `:8883`, Authelia `:9092`, CrowdSec `:6060`, CoreDNS, dnsdist | **Deployed** (Prometheus format, internal-only) |
| Metrics collection | Prometheus | **Not deployed** |
| Log aggregation | Loki + Promtail (or Vector) | **Not deployed** |
| Visualization | Grafana | **Not deployed** |
| Alert routing + inhibition | Alertmanager | **Not deployed** |
| Topology-aware correlation | Nothing | **Gap** |
| Internal uptime | Uptime Kuma | **Wishlist** |
| External uptime | `levonk/status` repo (Upptime) | **Exists** (separate repo) |
| Synthetic AI API probes | Nothing | **Gap** |

The existing docs (`traefik-authelia-cloudflare-monitoring.md`, `LITELLM-OPENLIT-COMPARISON.md`, `001-localnet-requirements.md`) list recommended tools but make **no decision** about alert correlation, topology-aware suppression, or synthetic probing. This ADR fills that gap.

### Problem Statement

> "I want to monitor my AI pipeline, my DNS pipeline, my web pipeline, etc. as the full chain so I can see chained failures clearly without getting flooded with non-root-cause issues."

This is a **topology-aware alert correlation** problem. The solution must:
- Model each pipeline as a directed dependency graph
- Detect failures at each node
- Suppress downstream alerts when an upstream node is the root cause
- Provide per-client isolation (each client gets their own monitoring instance)
- Include synthetic probes that validate end-to-end functionality (e.g., a token AI query through the OpenAI-compatible API to confirm the AI pipeline works, not just that containers are up)

## Constraints

- **Per-client isolation**: Each client submodule must have its own monitoring instance, alert rules, and notification channels. Shared directory contains schemas/defaults only; client-specific values in client submodule (per ADR-20260624001 and ADR-20260625001).
- **No secrets in shared/**: Monitoring credentials (Grafana admin password, Alertmanager SMTP/auth, synthetic probe API keys) stored in client vault (`infrahub-levonk-all.vault.yml`).
- **Variable-driven configuration**: All ports, IPs, domains for monitoring services must use `infra_` naming convention (per ADR-20260625001). No hardcoded values.
- **Ansible deployment**: All monitoring containers deployed via `community.docker` modules, never `docker compose` (per root AGENTS.md invariant #4).
- **Existing metrics endpoints**: Traefik, Authelia, CrowdSec, CoreDNS, dnsdist already expose Prometheus-format metrics. The solution must scrape these, not replace them.
- **Langfuse stays**: Langfuse is already deployed for AI pipeline tracing. This ADR does not replace it — Prometheus/Loki handle infrastructure metrics and logs; Langfuse handles AI-specific tracing (prompt chains, token usage, evaluations). See `LITELLM-OPENLIT-COMPARISON.md` for the prior decision.
- **External uptime stays separate**: The `levonk/status` repo (Upptime) handles external public-facing uptime via GitHub Actions. This ADR covers internal monitoring. The two systems are complementary and should not be merged.
- **Resource constraints**: Monitoring stack must run on the OCI cloud server alongside existing services. Prefer lightweight components (Loki over Elasticsearch, Alertmanager over a full AIOps platform).

## Decision

**Adopt a topology-aware observability stack with Alertmanager inhibition as the correlation engine, deployed per-client via Ansible roles, with synthetic OpenAI-compatible API probes for AI pipeline end-to-end validation.**

### 1. Monitoring Stack

| Layer | Tool | Role | Replaces/Augments |
|---|---|---|---|
| Metrics collection | **Prometheus** | Scrape all `/metrics` endpoints, store time series | — (new) |
| Log aggregation | **Loki** + **Promtail** | Collect Docker JSON logs, query via LogQL | — (new) |
| Visualization | **Grafana** | Dashboards for all pipelines, alert panels | — (new) |
| Alert routing + inhibition | **Alertmanager** | Route alerts, suppress downstream when upstream is root cause | — (new) |
| Internal uptime | **Uptime Kuma** | HTTP/TCP/ping probes for service availability | — (new) |
| AI pipeline tracing | **Langfuse** (existing) | LLM-specific tracing, prompt chains, token usage | Retained, not replaced |
| External uptime | **levonk/status** (Upptime, existing) | Public-facing status page via GitHub Actions | Retained, not replaced |
| Synthetic AI probes | **Custom probe script** (see §4) | End-to-end AI pipeline validation via OpenAI-compatible API | — (new) |

**Rejected alternatives:**
- **Elasticsearch/Kibana**: Too heavy for single-server deployment. Loki is 10x lighter for log storage.
- **SigNoz**: OpenTelemetry-native APM, but overlaps with Langfuse for AI tracing and lacks Alertmanager's mature inhibition rules.
- **Grafana OnCall**: Alert routing and on-call scheduling, but builds on top of Alertmanager — we can adopt it later if on-call rotation is needed. Start with Alertmanager alone.
- **BetterStack (free tier)**: Listed in `001-localnet-requirements.md` as a future option. Cloud-hosted, violates per-client isolation principle. Rejected for internal monitoring; could be used for external status if Upptime is insufficient.
- **OpenLIT**: Superset of Langfuse (GPU monitoring, eBPF, coding-agent hooks) but migration effort not justified per `LITELLM-OPENLIT-COMPARISON.md`. Langfuse retained.

### 2. Pipeline Dependency Graphs

Each pipeline is modeled as a directed graph. Edges represent "depends on" relationships. Alertmanager inhibition rules (§3) are derived from these graphs.

#### 2.1 AI Pipeline

The AI pipeline starts at **Omnigent** (the entry point where users/agents interact) and flows downstream through the chain to NordVPN (egress to the internet). Each node is monitored individually. The root cause is the **deepest failing node** — the first broken link when walking the chain from Omnigent downward. Only that node alerts; everything downstream of it (which is also broken, as a symptom) and everything upstream of it (which is up but can't complete work) is suppressed by Alertmanager inhibition.

```
ENTRY POINT
    │
    ▼
Omnigent ──depends on──> Pi ──depends on──> LiteLLM ──depends on──> Headroom
    │                                                                      │
    │                                                                      ▼
    │                                                                  OmniRoute ──depends on──> Forge
    │                                                                                               │
    │                                                                                               ▼
    │                                                                                          Iron-Proxy
    │                                                                                               │
    │                                                                                               ▼
    │                                                                                          NordVPN (egress)
    │                                                                                               │
    │                                                                                               ▼
    │                                                                                          Internet / LLM Provider
    │
    ▼
Supporting services:
  LiteLLM ──depends on──> LiteLLM Postgres
  LiteLLM ──depends on──> LiteLLM Redis
  Omnigent ──depends on──> Omnigent Postgres
  Langfuse Web ──depends on──> Langfuse Postgres, ClickHouse, Redis, MinIO, Worker
  All AI services ──depends on──> Traefik (ingress)
  All AI services ──depends on──> Authelia (auth)
  All AI services ──depends on──> DNS Pipeline (resolution)
```

**Per-node monitoring** (each node has its own health check, metrics, and alert rules):

| Stage | Node | Monitoring checks | Alert name | Labels |
|---|---|---|---|---|
| `agent` | Omnigent | Container health, `/health` endpoint, Omnigent Postgres connectivity, active session count | `OmnigentDown` | `pipeline=ai, stage=agent, service=omnigent` |
| `agent` | Pi | Container health, RPC endpoint responsiveness, Omnigent runner connectivity | `PiDown` | `pipeline=ai, stage=agent, service=pi` |
| `gateway` | LiteLLM | Container health, `/health` endpoint, `/v1/models` responds, Postgres + Redis connectivity, proxy throughput metrics | `LiteLLMDown` | `pipeline=ai, stage=gateway, service=litellm` |
| `compression` | Headroom | Container health, API endpoint responds, request latency | `HeadroomDown` | `pipeline=ai, stage=compression, service=headroom` |
| `routing` | OmniRoute | Container health, API endpoint responds, tier-fallback metrics, free-tier drain status | `OmniRouteDown` | `pipeline=ai, stage=routing, service=omniroute` |
| `forge` | Forge | Container health, API endpoint responds, tool-call success rate | `ForgeDown` | `pipeline=ai, stage=forge, service=forge` |
| `iron-proxy` | Iron-Proxy | Container health, HTTP/HTTPS proxy responds, upstream connectivity | `IronProxyDown` | `pipeline=ai, stage=iron-proxy, service=iron-proxy` |
| `egress` | NordVPN | Container health, WireGuard handshake, SOCKS/HTTP proxy responds, public IP changed (exit IP validation) | `NordVPNEgressDown` | `pipeline=ai, stage=egress, service=nordvpn` |
| `synthetic-probe` | (probe script) | End-to-end OpenAI-compatible API request with token-count validation (see §4.1) | `AIPipelineSyntheticProbeFailed` | `pipeline=ai, stage=synthetic-probe` |

**Root-cause identification logic** (walk the chain from Omnigent downward):

```
1. Is Omnigent down? → ROOT CAUSE = Omnigent. Alert on Omnigent only.
   (Everything downstream is healthy but idle — no alerts.)

2. Is Omnigent up but Pi down? → ROOT CAUSE = Pi. Alert on Pi only.
   (Omnigent can't complete work but is up — suppress Omnigent "can't complete" alerts.)
   (Everything downstream of Pi is healthy but idle — no alerts.)

3. Is Omnigent + Pi up but LiteLLM down? → ROOT CAUSE = LiteLLM. Alert on LiteLLM only.
   (Omnigent and Pi are up but can't complete work — suppress their "can't complete" alerts.)
   (Headroom, OmniRoute, Forge, Iron-Proxy, NordVPN are up but idle — no alerts.)

4. ... continue down the chain ...

8. Is everything up but NordVPN down? → ROOT CAUSE = NordVPN. Alert on NordVPN only.
   (All upstream nodes are up but can't complete work — suppress their alerts.)

9. Is everything up but synthetic probe fails? → ROOT CAUSE = unknown.
   (Some node is returning errors but not failing health checks — investigate.)
   (This is the "silent degradation" case: containers are up but the pipeline is broken.)
   Alert on synthetic probe, do NOT suppress per-node alerts (they might identify the issue).
```

**Key principle**: Per-node container health alerts fire only for the node that's actually broken. The inhibition rules suppress "can't complete work" alerts from upstream nodes (which are up but degraded) and the synthetic probe alert (which is a symptom, not a cause). The synthetic probe is the safety net — if all per-node health checks pass but the probe fails, something is silently degraded and needs investigation.

#### 2.2 DNS Pipeline

```
Client ──depends on──> AdGuard (filtering) ──depends on──> dnsdist (routing)
                                                              │
                                                              ▼
                                                         CoreDNS (internal zones)
                                                              │
                                                              ▼
                                                    DNSCrypt / Tor (anonymity)
                                                              │
                                                              ▼
                                                    Upstream resolvers (Cloudflare, etc.)

Cross-cluster failover:
  Local DNS chain fails → failover to cloud DNS chain via Tailscale IPs
  (see requirements/dns/cross-cluster-dns-failover.md)
```

**Per-node monitoring**:

| Stage | Node | Monitoring checks | Alert name | Labels |
|---|---|---|---|---|
| `filter` | AdGuard | Container health, DNS query endpoint, filter list freshness, query rate | `AdGuardDown` | `pipeline=dns, stage=filter, service=adguard` |
| `router` | dnsdist | Container health, DNS query endpoint, backend pool health, metrics endpoint | `DnsdistDown` | `pipeline=dns, stage=router, service=dnsdist` |
| `resolver` | CoreDNS | Container health, DNS query endpoint, internal zone resolution, metrics endpoint | `CoreDNSDown` | `pipeline=dns, stage=resolver, service=coredns` |
| `anonymity` | DNSCrypt/Tor | Container health, SOCKS5 proxy responds, Tor circuit established | `DNSAnonymityDown` | `pipeline=dns, stage=anonymity, service=dnscrypt-tor` |
| `synthetic-probe` | (probe script) | End-to-end DNS resolution (internal + external + DNSSEC) (see §4.2) | `DNSPipelineSyntheticProbeFailed` | `pipeline=dns, stage=synthetic-probe` |

**Root-cause identification** (walk from AdGuard downward): If AdGuard is down, alert on AdGuard only. If AdGuard is up but dnsdist is down, alert on dnsdist. If both are up but CoreDNS is down, alert on CoreDNS (AdGuard and dnsdist may still serve from cache but will eventually fail — suppress their "degraded" alerts). If everything is up but the synthetic probe fails, a resolver upstream is broken — investigate.

#### 2.3 Web Proxy Pipeline

```
Client ──depends on──> MITM Proxy ──depends on──> Privoxy ──depends on──> Varnish
                                                                       │
                                                                       ▼
                                                                    Gost (egress)
                                                                    │         │
                                                                    ▼         ▼
                                                                 Direct    Tor (shared with DNS chain)

Cross-cluster: NO failover (stateful: MITM sessions, cache, CA certs)
  Local cluster (dtop202311) and cloud cluster (oci-cloud-server) run independently.
```

**Per-node monitoring**:

| Stage | Node | Monitoring checks | Alert name | Labels |
|---|---|---|---|---|
| `interception` | MITM Proxy | Container health, proxy endpoint responds, CA cert validity, TLS handshake success | `MITMProxyDown` | `pipeline=web, stage=interception, service=mitmproxy` |
| `filtering` | Privoxy | Container health, proxy endpoint responds, filter rules loaded | `PrivoxyDown` | `pipeline=web, stage=filtering, service=privoxy` |
| `cache` | Varnish | Container health, HTTP endpoint responds, cache hit rate, stale-while-revalidate metrics | `VarnishDown` | `pipeline=web, stage=cache, service=varnish` |
| `egress` | Gost | Container health, SOCKS5 endpoint responds, backend connectivity (direct + Tor) | `GostDown` | `pipeline=web, stage=egress, service=gost` |
| `synthetic-probe` | (probe script) | End-to-end HTTP request through full proxy chain (see §4.3) | `WebProxyPipelineSyntheticProbeFailed` | `pipeline=web, stage=synthetic-probe` |

**Root-cause identification** (walk from MITM downward): If MITM is down, alert on MITM only. If MITM is up but Privoxy is down, alert on Privoxy. If both are up but Varnish is down, alert on Varnish (MITM and Privoxy are up but can't reach upstream — suppress their "can't complete" alerts). If Gost is down, Varnish serves stale cache but eventually fails — alert on Gost, suppress Varnish/Privoxy/MITM "degraded" alerts. If Tor (shared with DNS chain) is down, Gost falls back to direct — this is a warning, not critical.

#### 2.4 VPN/Egress Pipeline

```
All pipelines ──depend on──> Egress layer
  Egress options (per exit node):
    NordVPN (gluetun) ──depends on──> NordVPN servers (external)
    Tor ──depends on──> Tor network (external)
    WireGuard ──depends on──> WireGuard peer (external)
    Host-direct ──depends on──> Host internet connection

  Tailscale mesh ──depends on──> Tailscale coordination server (external)
```

**Per-node monitoring**:

| Stage | Node | Monitoring checks | Alert name | Labels |
|---|---|---|---|---|
| `mesh` | Tailscale | Tailscale daemon status, peer connectivity, exit node availability | `TailscaleDown` | `pipeline=vpn, stage=mesh, service=tailscale` |
| `egress-nordvpn` | NordVPN (gluetun) | Container health, WireGuard handshake, SOCKS/HTTP proxy, exit IP validation | `NordVPNDown` | `pipeline=vpn, stage=egress-nordvpn, service=nordvpn` |
| `egress-tor` | Tor | Container health, SOCKS5 proxy, Tor circuit established, ORPort reachable | `TorDown` | `pipeline=vpn, stage=egress-tor, service=tor` |
| `egress-wireguard` | WireGuard | WireGuard handshake, peer connectivity | `WireGuardDown` | `pipeline=vpn, stage=egress-wireguard, service=wireguard` |
| `egress-host` | Host-direct | Host internet connectivity (ping, DNS resolution) | `HostEgressDown` | `pipeline=vpn, stage=egress-host, service=host-direct` |
| `synthetic-probe` | (probe script) | Per-egress IP validation (see §4.4) | `VPNEgressSyntheticProbeFailed` | `pipeline=vpn, stage=synthetic-probe` |

**Root-cause identification**: Tailscale is the mesh layer — if it's down, all cross-cluster communication fails. Alert on Tailscale at highest priority and suppress all cross-cluster-dependent alerts. Each egress option (NordVPN, Tor, WireGuard, host-direct) is independent — if NordVPN is down, only services routing through NordVPN should alert; Tor/WireGuard/host-direct are unaffected. The synthetic probe checks each egress independently and labels which one failed.

### 3. Alertmanager Inhibition Rules

Inhibition = "if alert A is firing, suppress alert B." This is the core mechanism for root-cause suppression. The root cause is the **deepest failing node** in the chain — the first broken link when walking from the entry point (e.g., Omnigent) downward. Only that node's alert fires; everything else is suppressed.

**Two types of alerts that need inhibition:**
1. **"Can't complete work" alerts** — from upstream nodes that are up but can't reach the broken node (e.g., Omnigent is up but can't complete tasks because LiteLLM is down). These are symptoms, not causes.
2. **Synthetic probe alerts** — from the end-to-end probe that fails because some node in the chain is broken. The probe tells you "the pipeline is broken" but per-node monitoring tells you *which* node. Suppress the probe alert when a per-node root-cause alert is already firing.

**Important**: Per-node container health alerts (e.g., `OmnigentDown`, `LiteLLMDown`, `NordVPNDown`) only fire for the node that's actually broken. They do NOT fire for upstream nodes that are up but can't complete work — those nodes' container health checks pass. The inhibition rules below handle the "can't complete work" and synthetic probe alerts, not the per-node health alerts (which don't need inhibition because they only fire for the broken node).

**Rule structure** (in `alertmanager.yml`):

```yaml
inhibit_rules:
  # ── Cross-pipeline: VPN/egress is root cause ──
  # If VPN egress is down, all pipelines that depend on it are broken.
  # Suppress their "can't complete work" and synthetic probe alerts.
  - source_matchers:
      - pipeline="vpn"
      - severity="critical"
    target_matchers:
      - pipeline=~"ai|dns|web"
      - alert=~".*Degraded|.*SyntheticProbeFailed|.*CantComplete"
    equal: ['client']

  # ── Cross-pipeline: DNS is root cause ──
  # Web proxy depends on DNS for resolution. If DNS is down, web proxy is broken.
  - source_matchers:
      - pipeline="dns"
      - severity="critical"
    target_matchers:
      - pipeline="web"
      - alert=~".*Degraded|.*SyntheticProbeFailed|.*CantComplete"
    equal: ['client']

  # ── DNS pipeline: internal chain inhibition ──
  # CoreDNS (resolver) is root cause → suppress dnsdist/AdGuard "degraded" alerts
  # (they may still serve from cache but will eventually fail)
  - source_matchers:
      - pipeline="dns"
      - stage="resolver"
      - severity="critical"
    target_matchers:
      - pipeline="dns"
      - stage=~"filter|router"
      - alert=~".*Degraded|.*CantComplete"
    equal: ['client']

  # ── AI pipeline: walk from Omnigent downward ──
  # Each rule: if a node is down (root cause), suppress "can't complete" and
  # synthetic probe alerts from all nodes upstream of it in the chain.

  # NordVPN (egress) is root cause → suppress everything upstream in AI pipeline
  - source_matchers:
      - pipeline="ai"
      - stage="egress"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|gateway|compression|routing|forge|iron-proxy|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Iron-Proxy is root cause → suppress everything upstream of it
  - source_matchers:
      - pipeline="ai"
      - stage="iron-proxy"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|gateway|compression|routing|forge|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Forge is root cause → suppress everything upstream of it
  - source_matchers:
      - pipeline="ai"
      - stage="forge"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|gateway|compression|routing|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # OmniRoute (routing) is root cause → suppress everything upstream of it
  - source_matchers:
      - pipeline="ai"
      - stage="routing"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|gateway|compression|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Headroom (compression) is root cause → suppress everything upstream of it
  - source_matchers:
      - pipeline="ai"
      - stage="compression"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|gateway|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # LiteLLM (gateway) is root cause → suppress everything upstream of it
  - source_matchers:
      - pipeline="ai"
      - stage="gateway"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage=~"agent|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Pi (agent) is root cause → suppress Omnigent "can't complete" + synthetic probe
  - source_matchers:
      - pipeline="ai"
      - stage="agent"
      - service="pi"
      - severity="critical"
    target_matchers:
      - pipeline="ai"
      - stage="agent"
      - service="omnigent"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # ── Web proxy pipeline: walk from MITM downward ──
  # Gost (egress) is root cause → suppress everything upstream in web pipeline
  - source_matchers:
      - pipeline="web"
      - stage="egress"
      - severity="critical"
    target_matchers:
      - pipeline="web"
      - stage=~"interception|filtering|cache|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Varnish (cache) is root cause → suppress MITM/Privoxy "can't complete" + probe
  - source_matchers:
      - pipeline="web"
      - stage="cache"
      - severity="critical"
    target_matchers:
      - pipeline="web"
      - stage=~"interception|filtering|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # Privoxy (filtering) is root cause → suppress MITM "can't complete" + probe
  - source_matchers:
      - pipeline="web"
      - stage="filtering"
      - severity="critical"
    target_matchers:
      - pipeline="web"
      - stage=~"interception|synthetic-probe"
      - alert=~".*Degraded|.*CantComplete|.*SyntheticProbeFailed"
    equal: ['client']

  # ── Infrastructure: Traefik and Authelia are root cause for all UI services ──
  # Traefik is root cause → suppress all service-down alerts that depend on it
  - source_matchers:
      - service="traefik"
      - severity="critical"
    target_matchers:
      - alert=~"ServiceDown|HttpError|.*Degraded|.*CantComplete"
      - service!~"traefik|prometheus|loki|grafana|alertmanager|uptime-kuma"
    equal: ['client']

  # Authelia is root cause → suppress auth-failure alerts from downstream services
  - source_matchers:
      - service="authelia"
      - severity="critical"
    target_matchers:
      - alert=~"AuthFailure|AuthTimeout|.*CantComplete"
    equal: ['client']
```

**Alert labels** (every alert must include these for inhibition to work):

| Label | Values | Purpose |
|---|---|---|
| `client` | `levonk` | Per-client isolation |
| `pipeline` | `ai`, `dns`, `web`, `vpn`, `infra` | Which pipeline |
| `stage` | Pipeline-specific (e.g., `gateway`, `resolver`, `egress`) | Position in chain |
| `service` | Container/service name | Specific component |
| `severity` | `critical`, `warning`, `info` | Priority |

### 4. Synthetic Probes (End-to-End Validation)

Per-node monitoring (§2) tells you *which* node is broken. Synthetic probes tell you *whether the pipeline works end-to-end*. Both are needed:

- **Per-node health alerts** = primary alert source. If a node is down, its health alert fires and identifies the root cause.
- **Synthetic probe alerts** = safety net. If all nodes pass health checks but the pipeline still fails (silent degradation, misconfiguration, network issue between nodes), the probe catches it. The probe alert is suppressed by inhibition when a per-node root-cause alert is already firing (see §3).

Container-level healthchecks tell you a container is running, not that the pipeline works. Synthetic probes exercise the full chain from entry point to egress.

#### 4.1 AI Pipeline Synthetic Probe (OpenAI-compatible API)

The AI pipeline starts at Omnigent (the entry point). The synthetic probe exercises the full chain from Omnigent's perspective — it sends a request through the OpenAI-compatible API and validates that a real LLM response comes back with token counts. This validates every hop:

1. **Omnigent** — entry point is up and accepting requests
2. **Pi** — agent harness is responsive
3. **Traefik routing** — request reaches LiteLLM via `litellm.<base>/v1/chat/completions`
4. **Authelia auth** — if the endpoint requires auth (or LiteLLM virtual key auth)
5. **LiteLLM gateway** — request is accepted, routed to a provider
6. **Headroom** — context compression (if request is large enough to trigger it)
7. **OmniRoute** — provider routing and fallback
8. **Forge** — tool calling layer (if the probe includes a tool-use request)
9. **Iron-Proxy** — egress proxy
10. **NordVPN** — actual internet egress to the LLM provider
11. **Response parsing** — a valid OpenAI-format response returns with token counts

**Two probe variants** (run both):

| Probe | Entry point | What it validates | When to use |
|---|---|---|---|
| **Omnigent probe** | Omnigent web UI / API | Full chain from user entry point: Omnigent → Pi → LiteLLM → ... → NordVPN → LLM | Confirms the user-facing experience works |
| **LiteLLM probe** | LiteLLM `/v1/chat/completions` | Gateway-to-egress chain: LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN → LLM | Isolates gateway issues from Omnigent/Pi issues |

If the Omnigent probe fails but the LiteLLM probe passes, the root cause is between Omnigent and LiteLLM (Omnigent or Pi). If both fail, the root cause is at LiteLLM or downstream. This narrows the diagnostic scope.

**Probe specification:**

```yaml
# Deployed via Ansible as a sidecar or cron container
# Probe 1: Omnigent entry point (full chain)
probe_ai_pipeline_omnigent:
  name: "AI Pipeline Synthetic Probe (Omnigent entry)"
  interval: "5m"
  timeout: "30s"
  # Sends a minimal agent task through Omnigent that triggers an LLM call
  # via Pi → LiteLLM → ... → NordVPN → LLM provider
  endpoint: "{{ infra_domain_ai_omnigent }}/api/v1/sessions"
  auth:
    header: "Authorization"
    value: "Bearer {{ vault_omnigent_synthetic_probe_key }}"  # vault-owned
  request:
    # Minimal agent session that makes one LLM call and returns
    action: "probe"
    prompt: "Reply with exactly: OK"
    max_tokens: 5
  expected_response:
    status: 200
    # Validate that the LLM call completed (token usage present)
    json_path:
      usage.total_tokens: "exists"
      response.content: "contains:OK"
  on_failure:
    alert:
      name: "AIPipelineSyntheticProbeFailed"
      labels:
        pipeline: "ai"
        stage: "synthetic-probe"
        service: "omnigent-probe"
        severity: "critical"
      annotations:
        summary: "AI pipeline end-to-end probe failed (Omnigent entry) — full chain broken"
        description: "Synthetic request from Omnigent failed. Walk the chain: Omnigent → Pi → LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN."

# Probe 2: LiteLLM entry point (gateway-to-egress)
probe_ai_pipeline_litellm:
  name: "AI Pipeline Synthetic Probe (LiteLLM entry)"
  interval: "5m"
  timeout: "30s"
  endpoint: "{{ infra_domain_ai_litellm_api }}/v1/chat/completions"
  auth:
    header: "Authorization"
    value: "Bearer {{ vault_litellm_synthetic_probe_key }}"  # vault-owned
  request:
    model: "gpt-4o-mini"  # cheap model, minimal tokens
    messages:
      - role: "user"
        content: "Reply with exactly: OK"
    max_tokens: 5
    temperature: 0
  expected_response:
    status: 200
    body_contains: "OK"
    # Validate token usage is present (confirms full pipeline processed the request)
    json_path:
      usage.total_tokens: "exists"
      choices[0].message.content: "contains:OK"
  on_failure:
    alert:
      name: "AIPipelineGatewayProbeFailed"
      labels:
        pipeline: "ai"
        stage: "synthetic-probe"
        service: "litellm-probe"
        severity: "critical"
      annotations:
        summary: "AI pipeline gateway probe failed — LiteLLM-to-egress chain broken"
        description: "Synthetic OpenAI-compatible API request to LiteLLM failed. Check LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN chain."
```

**Why token-counted:** The probe validates that `usage.total_tokens` is present in the response. This confirms the request actually reached an LLM provider and was processed — not just that LiteLLM returned a cached error or a 200 with an empty body. Token counts are the AI-pipeline equivalent of a TCP handshake: they prove the full round-trip completed.

**Diagnostic flow when probe fails:**
```
Omnigent probe fails?
  ├─ Yes → LiteLLM probe also fails?
  │         ├─ Yes → Root cause is at LiteLLM or downstream (check per-node alerts)
  │         └─ No  → Root cause is Omnigent or Pi (check per-node alerts)
  └─ No  → Pipeline is healthy (probe passed)
```

**Cost:** At `gpt-4o-mini` with `max_tokens: 5`, each probe costs ~$0.0001. Two probes at 5-minute intervals = ~$17.52/year. Negligible.

#### 4.2 DNS Pipeline Synthetic Probe

```yaml
probe_dns_pipeline:
  name: "DNS Pipeline Synthetic Probe"
  interval: "2m"
  queries:
    - domain: "{{ infra_domain_base }}"  # internal zone
      expected: "resolved"
      validates: "CoreDNS internal zones"
    - domain: "cloudflare.com"  # external
      expected: "resolved"
      validates: "Full DNS chain → upstream resolver"
    - domain: "dnssec-test.dnssec-tools.org"  # DNSSEC validation
      expected: "resolved"
      validates: "DNSCrypt/Tor path (if routed through anonymity chain)"
  on_failure:
    alert:
      name: "DNSPipelineSyntheticProbeFailed"
      labels:
        pipeline: "dns"
        stage: "synthetic-probe"
        severity: "critical"
```

#### 4.3 Web Proxy Pipeline Synthetic Probe

```yaml
probe_web_pipeline:
  name: "Web Proxy Pipeline Synthetic Probe"
  interval: "5m"
  request:
    url: "http://example.com"  # via web proxy chain
    proxy: "http://{{ infra_network_ip_proxy_mitm }}:{{ infra_port_proxy_mitm_adblock_container }}"
    expected_status: 200
  on_failure:
    alert:
      name: "WebProxyPipelineSyntheticProbeFailed"
      labels:
        pipeline: "web"
        stage: "synthetic-probe"
        severity: "critical"
```

#### 4.4 VPN/Egress Synthetic Probe

```yaml
probe_vpn_egress:
  name: "VPN/Egress Synthetic Probe"
  interval: "5m"
  checks:
    - name: "NordVPN egress"
      command: "curl --socks5 {{ infra_network_ip_vpn_nordvpn }}:{{ infra_port_vpn_nordvpn_socks_container }} -s https://api.ipify.org"
      expected_not: "{{ host_public_ip }}"  # confirms traffic is exiting via VPN, not direct
    - name: "Tor egress"
      command: "curl --socks5-hostname {{ infra_network_ip_dns_tor_proxy }}:{{ infra_port_proxy_tor_socks5_container }} -s https://check.torproject.org/api/ip"
      expected_contains: "true"  # confirms Tor exit
    - name: "Tailscale mesh"
      command: "tailscale status"
      expected_contains: "active"
  on_failure:
    alert:
      name: "VPNEgressSyntheticProbeFailed"
      labels:
        pipeline: "vpn"
        stage: "synthetic-probe"
        severity: "critical"
```

### 5. Per-Client Isolation

Following ADR-20260624001 (hybrid secret storage) and ADR-20260625001 (infrastructure consolidation):

| Concern | Shared (schema/defaults) | Client (values/overrides) |
|---|---|---|
| Monitoring ports | `shared/.../infrastructure/ports.yml` (`infra_port_monitoring_*`) | `levonk/.../infrastructure/ports.yml` (overrides) |
| Monitoring domains | `shared/.../infrastructure/domains.yml` (`infra_domain_monitoring_*`) | `levonk/.../infrastructure/domains.yml` (overrides) |
| Alert rules (templates) | `shared/.../ansible/roles/monitoring-alertmanager/templates/` | Client-specific overrides in `levonk/.../ansible/` |
| Notification channels | — | `levonk/.../group_vars/infrahub-levonk-all.vault.yml` (SMTP, Slack, ntfy credentials) |
| Synthetic probe API keys | — | `levonk/.../group_vars/infrahub-levonk-all.vault.yml` (`vault_litellm_synthetic_probe_key`) |
| Grafana admin password | — | `levonk/.../group_vars/infrahub-levonk-all.vault.yml` (`vault_grafana_admin_password`) |

**Each client gets:**
- Its own Prometheus instance (scraping that client's hosts)
- Its own Grafana instance (dashboards for that client's services)
- Its own Alertmanager (with that client's inhibition rules and notification channels)
- Its own Uptime Kuma instance (probing that client's services)
- Its own synthetic probes (using that client's vault-owned API keys)

**When a second client is added**, deploy a second monitoring stack for that client. Do not share a single Prometheus/Grafana across clients — this violates client isolation.

### 6. Ansible Role Structure

```
shared/active/02-config/ansible/roles/
├── monitoring-prometheus/        # Prometheus deployment + scrape configs
│   ├── defaults/main.yml         # Default ports, retention, scrape intervals
│   ├── templates/prometheus.yml.j2  # Scrape config (references infra_ port vars)
│   └── tasks/main.yml            # community.docker.docker_container
├── monitoring-loki/              # Loki + Promtail
├── monitoring-grafana/           # Grafana + datasource provisioning
├── monitoring-alertmanager/      # Alertmanager + inhibition rules
│   └── templates/alertmanager.yml.j2  # Inhibition rules (§3)
├── monitoring-uptime-kuma/       # Uptime Kuma deployment
└── monitoring-synthetic-probes/  # Probe scripts as cron/sidecar containers
    ├── templates/ai-probe.sh.j2
    ├── templates/dns-probe.sh.j2
    ├── templates/web-probe.sh.j2
    └── templates/vpn-probe.sh.j2
```

**Playbook**: `shared/active/02-config/ansible/playbooks/deploy-monitoring-stack.yml`

**Just recipes** (to be added to justfile):
- `just ansible-deploy-monitoring` — deploy full monitoring stack
- `just ansible-validate-monitoring` — validate stack health

### 7. Infrastructure Variables (new)

Add to `shared/active/02-config/ansible/infrastructure/ports.yml`:

```yaml
# Monitoring
infra_port_monitoring_prometheus_host: "9090"
infra_port_monitoring_prometheus_container: "9090"
infra_port_monitoring_grafana_host: "3000"
infra_port_monitoring_grafana_container: "3000"
infra_port_monitoring_loki_host: "3100"
infra_port_monitoring_loki_container: "3100"
infra_port_monitoring_alertmanager_host: "9093"
infra_port_monitoring_alertmanager_container: "9093"
infra_port_monitoring_uptime_kuma_host: "3001"
infra_port_monitoring_uptime_kuma_container: "3001"
```

Add to `shared/active/02-config/ansible/infrastructure/domains.yml`:

```yaml
infra_domain_monitoring_grafana: "grafana.{{ infra_domain_base }}"
infra_domain_monitoring_alertmanager: "alerts.{{ infra_domain_base }}"
infra_domain_monitoring_uptime_kuma: "uptime.{{ infra_domain_base }}"
infra_domain_monitoring_prometheus: "prometheus.{{ infra_domain_base }}"  # internal-only, no Traefik exposure
```

### 8. Notification Channels

Alertmanager routes alerts to notification channels. Per-client configuration in vault:

| Channel | Use case | Config location |
|---|---|---|
| **ntfy** | Primary — push notifications to phone | `vault_monitoring_ntfy_url` in client vault |
| **Email (SMTP)** | Secondary — email for critical alerts | `vault_monitoring_smtp_*` in client vault |
| **Slack webhook** | Optional — if Slack workspace exists | `vault_monitoring_slack_webhook` in client vault |

**Routing rules:**
- `severity=critical` → ntfy + email
- `severity=warning` → ntfy only
- `severity=info` → Grafana dashboard only (no push)

## Consequences

### Positive

1. **Root-cause visibility**: Per-node monitoring at every pipeline stage identifies which node is broken. Alertmanager inhibition suppresses "can't complete work" alerts from upstream nodes and synthetic probe alerts, so you get one alert from the root cause, not a flood. When NordVPN goes down, you get `NordVPNEgressDown` — not seven cascading alerts from Iron-Proxy, Forge, OmniRoute, Headroom, LiteLLM, Pi, and Omnigent.
2. **Walk-from-entry-point diagnostic**: The AI pipeline monitoring starts at Omnigent (the entry point) and walks downstream. Per-node health checks identify the first broken link. Two synthetic probes (Omnigent entry + LiteLLM entry) narrow the diagnostic scope: if the Omnigent probe fails but the LiteLLM probe passes, the root cause is between Omnigent and LiteLLM.
3. **End-to-end validation**: Synthetic probes confirm the full pipeline works, not just that containers are running. The AI probe with token-count validation proves the entire chain (Omnigent → Pi → LiteLLM → ... → NordVPN → LLM provider) completed a round-trip.
4. **Per-client isolation**: Each client has their own monitoring stack. No cross-client data leakage. Consistent with ADR-20260624001 and ADR-20260625001.
5. **Leverages existing endpoints**: Traefik, Authelia, CrowdSec, CoreDNS, dnsdist already expose Prometheus metrics. No need to instrument services that already have metrics.
6. **Langfuse retained**: AI-specific tracing (prompt chains, token usage, evaluations) stays in Langfuse. Prometheus handles infrastructure metrics; Langfuse handles AI semantics. No overlap.
7. **External uptime stays separate**: `levonk/status` repo continues to handle public-facing status. Internal monitoring is separate and more detailed.
8. **Lightweight**: Loki over Elasticsearch, Alertmanager over a full AIOps platform. Fits on the OCI cloud server alongside existing services.

### Negative

1. **New services to maintain**: Prometheus, Loki, Grafana, Alertmanager, Uptime Kuma = 5 new containers per client. Adds operational complexity.
2. **Resource usage**: Prometheus + Loki + Grafana will consume ~1-2GB RAM and non-trivial disk for metrics/log retention. Need to configure retention policies.
3. **Inhibition rules require maintenance**: When pipeline topology changes (e.g., a new service is added), inhibition rules must be updated. The pipeline dependency graphs in §2 are the source of truth — update them first, then update alert rules.
4. **Synthetic probe costs**: Two AI pipeline probes (Omnigent + LiteLLM) cost ~$17.52/year at current rates. Negligible but non-zero. Monitor spend via LiteLLM's existing spend tracking.
5. **Alert fatigue risk if inhibition is misconfigured**: If inhibition rules are too aggressive, real downstream failures could be suppressed. Mitigation: inhibition only suppresses when `severity=critical` on the source alert; warnings always pass through.

### Risks

1. **Monitoring stack itself fails**: If Prometheus is down, no alerts fire. Mitigation: Uptime Kuma probes Prometheus and Alertmanager independently; if monitoring stack is down, Uptime Kuma's own notification channel (separate from Alertmanager) fires.
2. **Inhibition masks real issues**: If a downstream service fails independently of an upstream that also happens to be down, the downstream alert is suppressed. Mitigation: this is rare and the trade-off (one missed alert vs. seven duplicate alerts) is acceptable. The `equal: ['client']` constraint prevents cross-client suppression.
3. **Synthetic probe false positives**: If the LLM provider is down (not our pipeline), the AI probe fails and alerts. Mitigation: LiteLLM's fallback routing should handle provider outages; if all providers are down, that's a real alert. Distinguish "our pipeline is broken" from "all LLM providers are down" by checking LiteLLM's `/health` endpoint separately.
4. **Disk exhaustion from logs/metrics**: Loki and Prometheus can consume significant disk. Mitigation: configure retention (e.g., 30 days for metrics, 14 days for logs) and monitor disk usage with an alert when usage > 80%.
5. **Per-client stack duplication**: Each new client adds 5 containers. For 3+ clients, consider a shared Prometheus with per-client tenants (Prometheus multi-tenancy via labels). Out of scope for this ADR — revisit when second client is added.

## Implementation Plan

### Phase 1: Infrastructure Variables + Ansible Roles
- [ ] Add monitoring ports/domains to `shared/.../infrastructure/ports.yml` and `domains.yml`
- [ ] Add client overrides to `levonk/.../infrastructure/ports.yml` and `domains.yml`
- [ ] Create Ansible roles: `monitoring-prometheus`, `monitoring-loki`, `monitoring-grafana`, `monitoring-alertmanager`, `monitoring-uptime-kuma`
- [ ] Create `deploy-monitoring-stack.yml` playbook
- [ ] Add `just ansible-deploy-monitoring` and `just ansible-validate-monitoring` recipes

### Phase 2: Per-Node Monitoring + Alert Rules
- [ ] Encode pipeline dependency graphs (§2) as Prometheus alert rules with `pipeline`, `stage`, `service`, `severity` labels
- [ ] Create per-node alert rules for every node in each pipeline (AI: Omnigent, Pi, LiteLLM, Headroom, OmniRoute, Forge, Iron-Proxy, NordVPN; DNS: AdGuard, dnsdist, CoreDNS, DNSCrypt/Tor; Web: MITM, Privoxy, Varnish, Gost; VPN: Tailscale, NordVPN, Tor, WireGuard, host-direct)
- [ ] Create "can't complete work" alert rules for upstream nodes (fire when a node is up but its downstream dependency is down)
- [ ] Configure Alertmanager inhibition rules (§3) — walk-from-entry-point downward suppression
- [ ] Configure notification channels (ntfy, email) in client vault

### Phase 3: Synthetic Probes
- [ ] Create `monitoring-synthetic-probes` role
- [ ] Deploy AI pipeline Omnigent probe (full chain from entry point, token-count validation)
- [ ] Deploy AI pipeline LiteLLM probe (gateway-to-egress chain, token-count validation)
- [ ] Deploy DNS pipeline probe
- [ ] Deploy web proxy pipeline probe
- [ ] Deploy VPN/egress probe
- [ ] Wire probe failures into Prometheus/Alertmanager
- [ ] Verify probe alerts are suppressed by inhibition when per-node root-cause alerts are firing

### Phase 4: Grafana Dashboards
- [ ] Create per-pipeline dashboards (AI, DNS, Web, VPN)
- [ ] Create cross-pipeline "root cause" dashboard showing inhibited vs. firing alerts
- [ ] Create synthetic probe status dashboard
- [ ] Provision dashboards via Grafana provisioning (GitOps-style, no manual dashboard creation)

### Phase 5: Vault Secrets
- [ ] Add `vault_litellm_synthetic_probe_key` to client vault (LiteLLM virtual key with $1 spend limit, restricted to `gpt-4o-mini`)
- [ ] Add `vault_omnigent_synthetic_probe_key` to client vault (Omnigent API key for probe session creation)
- [ ] Add `vault_grafana_admin_password` to client vault
- [ ] Add `vault_monitoring_ntfy_url` to client vault
- [ ] Add `vault_monitoring_smtp_*` to client vault
- [ ] Provide user with docker run command to edit vault (per AGENTS.md vault edit workflow)

### Phase 6: Validation
- [ ] Verify Prometheus scrapes all existing metrics endpoints
- [ ] Verify Loki collects Docker logs from all containers
- [ ] Verify Grafana dashboards render with data
- [ ] Verify per-node alerts fire for the correct node (stop Omnigent → only `OmnigentDown` fires, not `LiteLLMDown`)
- [ ] Verify Alertmanager inhibition works (stop NordVPN → `NordVPNEgressDown` fires, all upstream "can't complete" and synthetic probe alerts are suppressed)
- [ ] Verify walk-from-entry-point logic (stop LiteLLM → `LiteLLMDown` fires, Omnigent/Pi "can't complete" alerts suppressed, Headroom/OmniRoute/Forge/Iron-Proxy/NordVPN do not alert)
- [ ] Verify synthetic probes detect real failures (stop a service, confirm probe alerts)
- [ ] Verify synthetic probe is suppressed when per-node root-cause alert is firing (stop LiteLLM → `LiteLLMDown` fires, `AIPipelineSyntheticProbeFailed` is suppressed)
- [ ] Verify synthetic probe fires when all nodes are up but pipeline is broken (misconfigure a service → probe fails, no per-node alerts)
- [ ] Verify AI pipeline Omnigent probe returns token counts (confirms full round-trip from entry point)
- [ ] Verify AI pipeline LiteLLM probe returns token counts (confirms gateway-to-egress round-trip)
- [ ] Verify diagnostic flow (Omnigent probe fails + LiteLLM probe passes → root cause is Omnigent or Pi)
- [ ] Verify notification channels deliver alerts (ntfy, email)

## ADR Compliance

- **ADR-20260624001**: All monitoring secrets in client vault, not in shared/
- **ADR-20260625001**: All monitoring ports/IPs/domains use `infra_` naming convention
- **Root AGENTS.md**: All containers deployed via `community.docker` modules, never `docker compose`
- **Root AGENTS.md**: No hardcoded IPs or ports in alert rules or probe configs — all via `infra_` variables

## References

- `shared/active/08-docs/network/traefik-authelia-cloudflare-monitoring.md` — existing per-service metrics endpoints
- `shared/active/03-container/services/ai-dashboard/LITELLM-OPENLIT-COMPARISON.md` — Langfuse vs OpenLIT decision (Langfuse retained)
- `shared/active/03-container/internal-docs/requirements/proxy/cross-cluster-web-proxy.md` — web proxy chain topology and DNS dependency
- `shared/active/03-container/internal-docs/requirements/001-localnet-requirements/001-localnet-requirements.md` — original monitoring stack wishlist (this ADR supersedes the wishlist with a decision)
- `shared/active/02-config/ansible/infrastructure/services.yml` — service catalog with machines, categories, ports
- `shared/docs/PIPELINE-AI.md` — AI pipeline architecture and troubleshooting
- ADR-20260624001: Hybrid Sensitive Information Storage Strategy
- ADR-20260625001: Infrastructure Consolidation Strategy
- ADR-20260625001: Multi-Exit Node Architecture
- [Prometheus Alertmanager inhibition docs](https://prometheus.io/docs/alerting/latest/notification_examples/)
- [Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Grafana Loki](https://github.com/grafana/loki)
- `levonk/status` repo — external uptime monitoring (Upptime)

## Revision History

- 2026-08-27: Initial ADR creation — proposed, pending review
