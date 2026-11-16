# ADR-20261115001: WAN Bonding Endpoint (MPTCP aggregation) on OCI

## Status

**Proposed — NOT YET DEPLOYED** - 2026-11-15

Automation and documentation are committed; no live host has been touched.
`deploy-wanbonding.yml` carries a `NOT YET DEPLOYED — manual approval
required` header and the justfile recipes are marked accordingly.

## Context

The home LAN has two WAN links (Spectrum cable + T-Mobile 5G home internet).
Today OPNsense (planned, on Proxmox x86) or an OpenWrt/mwan3 router can only
do *failover* or *per-flow load balancing* — a single TCP connection can
never exceed the speed of one WAN. True bonding requires spreading the
packets of a **single flow** across both WANs.

### Why a remote endpoint is mandatory

True single-flow bonding cannot be done on-premises:

1. **TCP four-tuple identity.** A TCP connection is identified by
   (src ip, src port, dst ip, dst port). A NAT router can pin one connection
   to one WAN or balance *different connections* across WANs, but it cannot
   split one connection's packets across two egress IPs without breaking
   the flow's identity at the far end.
2. **MPTCP needs both endpoints.** Multipath TCP (RFC 8684) is a TCP
   option — both the client side and the server side must negotiate it.
   Arbitrary internet servers don't support it, so the LAN side must
   terminate application TCP at a *proxy* and run MPTCP on the
   proxy-to-endpoint leg. That requires a remote endpoint we control.
3. **Single public egress IP.** The remote endpoint re-originates traffic
   toward the internet from one stable IP, so remote servers see a
   consistent source regardless of which WAN carried the subflows.

This is the OpenMPTCProuter (OMR) server pattern: the client router runs
shadowsocks + glorytun toward a VPS; we replicate the server half on our
own OCI VM.

### Options evaluated

| Option | Verdict | Reason |
|---|---|---|
| OpenMPTCProuter VPS install script | ❌ Rejected | x86-only; the OCI Ampere A1 host and guest are **arm64**. |
| DIY shadowsocks-libev + glorytun | ✅ **Chosen** | Same stack OMR uses, packageable for arm64; shadowsocks gives TCP proxying the guest kernel can run as MPTCP; glorytun covers non-TCP. |
| WireGuard multipath | ❌ Rejected | A WG tunnel is a *single UDP flow*. Multipath/ECMP hashing spreads **flows** across WANs, never **packets of one flow** — single-flow throughput stays capped at one WAN. Fine for failover, not bonding. |
| mlvpn | ❌ Rejected | Per-packet round-robin across links with asymmetric latency (cable vs 5G) causes severe reordering; needs constant reorder-buffer tuning. |
| SlaNet / commercial bonded VPN | ❌ Rejected | Third-party egress, subscription cost, and less control than a VM we own. |

### Component roles

| Component | Path | Why |
|---|---|---|
| **shadowsocks-libev** (`ss-server --mptcp`) | TCP proxy, port `tcp/65101` | Every proxied app connection becomes a TCP session router→VPS. The client kernel's MPTCP stack stripes subflows across both WANs; the guest kernel terminates them. Survives a WAN loss (remaining subflows continue). |
| **glorytun UDP** (`glorytun`) | UDP VPN, port `udp/65001` | MPTCP is TCP-only — UDP/ICMP/other protocols ride this VPN to the same endpoint. Lowest latency; no head-of-line. **Default.** |
| **glorytun TCP** (`glorytun-tcp` with `mptcp` flag) | TCP VPN, port `tcp/65001` | Alternative variant: aggregates like shadowsocks but inner latency-sensitive traffic suffers TCP-in-TCP head-of-line and ordering stalls. Disabled by default (`wanbonding_glorytun_variant: "tcp"` to switch). |

## Decision

Run the server half in a **dedicated KVM guest — `bonding-vm`** — on
`oci-cloud-server` (OCI Ampere A1, arm64 host **and** guest), provisioned by
the existing `isolation-vm` role (same QEMU/virt-install + NAT/routed bridge
pattern as `isolation-vm`; new `isolation_vm_cloud_init_enabled` flag wires
the already-rendered cloud-init seed into `--cloud-init`).

- **Guest**: Debian bookworm arm64 cloud image, static IP
  `192.168.100.148` on `kvm-nat-br0` (DHCP reservation by MAC), routed
  bridge `kvm-route-br0` also attached.
- **Kernel layer (host-level, sanctioned exception to container-first)**:
  `net.mptcp.enabled=1`, `ip mptcp` limits, BBR+fq, `ip_forward`, and a
  oneshot systemd unit reapplying `ip mptcp` state at boot.
- **Userspace (containers, host-networked)**: one arm64 image
  `localnet-net-wanbonding` (built on the amd64 Mac via `docker buildx`,
  pushed to the OCI registry, pulled by Ansible). Runs three daemons:
  `ss-server --mptcp`, `glorytun` (UDP), `glorytun-tcp` (TCP variant).
  Host networking is required: tunnel listeners must bind the VM's bridge
  IP directly — Docker bridge NAT would add a second DNAT hop and obscure
  client source IPs.
- **Host firewall**: firewalld `forward-port` rich rules DNAT the WAN
  ports from the host's public interface into `192.168.100.148`
  (`wanbonding_host_forward_ports`; nftables path also provided).
- **OCI VCN security list**: ingress `tcp/65101`, `udp/65001` (+
  `tcp/65001` if the TCP variant is enabled), source `0.0.0.0/0` —
  **manual console step, not managed by Ansible.**

### Security boundary & rollback

- The WAN-facing daemons live inside the guest, not on the host kernel —
  a compromise reaches the VM, not the hypervisor hosting other workloads.
- The guest image is a plain qcow2 in the libvirt storage pool: snapshot
  with `virsh snapshot-create-as bonding-vm` before upgrades for instant
  rollback.
- `bonding-vm` is a **separate** VM — the existing `isolation-vm` has a
  different security purpose and is not overloaded.
- Guest nftables: default-deny input; only `tcp/22` (SSH) from the KVM
  bridge subnets + tailnet, and the WAN service ports from anywhere.
- Secrets (`shadowsocks` PSK, `glorytun` keyfile) live in the levonk vault
  (`vault_wanbonding_*`); key material is templated to root-only files.

### Bandwidth / overhead analysis

| Factor | Expected value | Notes |
|---|---|---|
| shadowsocks + MPTCP TCP throughput | ~85–95% of combined link | Symmetric links. On asymmetric-latency pairs (cable ~15ms vs 5G ~40–80ms jitter) degrade toward slower-link + 60–80% of faster-link — reordering cost that schedulers mitigate but cannot eliminate. |
| glorytun UDP overhead | ~30–60 B/packet | ChaCha AEAD + tunnel headers. |
| glorytun TCP alternative | TCP-like aggregation | Adds head-of-line/ordering stalls for inner latency-sensitive traffic. |
| AEAD + encapsulation total | ~50–100 B | → MTU/MSS clamp required. |
| **Chosen tunnel MTU** | **1280** | glorytun default; MSS clamp via `iptables -t mangle TCPMSS --clamp-mss-to-pmtu` convention (client-side too). |
| Server CPU | non-issue | Ampere A1 arm64 has AES instructions and headroom. |
| Client CPU | ~200–500 Mbps cap | AES-GCM on router-class SoCs is the usual bottleneck; OPNsense on Proxmox x86 has more headroom — note it, don't size for it. |
| OCI egress | 10 TB/mo free tier | All bonded traffic hairpins through OCI — both directions consume egress. Assumed sufficient for typical use; **monitor quota** (OCI console usage reports). |
| Latency | +RTT to OCI region | All traffic transits the cloud — pick the nearest OCI region (already chosen by the existing host). |

### glorytun UDP vs TCP choice (documented default: UDP)

- **UDP (default)**: single UDP tunnel, per-packet delivery, minimal
  latency impact, no head-of-line blocking. Client-side aggregation of the
  UDP tunnel itself can be handled by the OMR glorytun multipath patches or
  left single-path (non-TCP traffic is usually a minority share).
- **TCP**: the tunnel connection itself can be MPTCP (`mptcp` flag), so it
  aggregates across WANs like shadowsocks — but tunneled UDP/ICMP packets
  suffer TCP ordering + retransmit semantics (head-of-line). Choose it only
  if non-TCP bulk traffic needs true bonding and can tolerate the
  ordering cost.

## Client-side contract (OPNsense / OpenWrt input spec)

A future agent wiring the LAN side needs exactly these inputs. All values
are in `shared/.../infrastructure/ports.yml` + `networks.yml` (names in
parens) — do **not** re-derive.

### Connection parameters

| Input | Variable | Value |
|---|---|---|
| Server address | — | OCI public IP (`100.90.22.85` at time of writing) or a DNS alias you create |
| shadowsocks server port | `infra_port_net_wanbonding_shadowsocks_host` | `65101/tcp` |
| shadowsocks cipher | `wanbonding_shadowsocks_method` | `aes-256-gcm` |
| shadowsocks password | `vault_wanbonding_shadowsocks_password` | (vault — `scripts/edit-vault.sh`) |
| shadowsocks mode | `wanbonding_shadowsocks_mode` | `tcp_only` (UDP rides glorytun — no ss UDP relay) |
| glorytun UDP endpoint port | `infra_port_net_wanbonding_glorytun_udp_host` | `65001/udp` |
| glorytun UDP client listen port | `infra_port_net_wanbonding_glorytun_udp_client` | `5000/udp` (client binds this; server replies to it) |
| glorytun TCP endpoint port | `infra_port_net_wanbonding_glorytun_tcp_host` | `65001/tcp` (only if variant `tcp`) |
| glorytun shared key | `vault_wanbonding_glorytun_key` | (vault — same keyfile on both ends) |
| glorytun UDP options | `wanbonding_glorytun_udp_options` | `chacha persist` |
| glorytun TCP options | `wanbonding_glorytun_tcp_options` | see defaults (chacha20/retry/keepalive/multiqueue) |

### Tunnel point-to-point addressing

| Tunnel | Subnet | Server (VPS) | Client (router) |
|---|---|---|---|
| glorytun UDP | `10.255.254.0/24` (`infra_network_wanbonding_glorytun_udp_subnet`) | `10.255.254.1` | `10.255.254.2` |
| glorytun TCP | `10.255.255.0/24` (`infra_network_wanbonding_glorytun_tcp_subnet`) | `10.255.255.1` | `10.255.255.2` |

### MTU / MSS

- glorytun tunnel MTU: **1280** (`wanbonding_glorytun_mtu`).
- Clamp TCP MSS to PMTU on the router for traffic entering the
  shadowsocks/glorytun paths (`--clamp-mss-to-pmtu` in the mangle table).
- Overhead budget: ~50–100 B for AEAD + encapsulation — 1280 is
  deliberately conservative for 5G paths.

### Expected routing entries (client side)

- Default route via `10.255.254.1` (UDP variant) or `10.255.255.1` (TCP
  variant) for non-TCP traffic — i.e., policy-route everything that isn't
  shadowsocks-proxied into `gt-udp0`.
- TCP traffic → local shadowsocks client (transparent proxy, OMR style:
  `ss-redir` + iptables TPROXY/REDIRECT rules), which opens MPTCP
  connections to `65101/tcp`.
- The shadowsocks server IP itself must be reachable over **both** WANs
  (per-WAN host routes for the endpoint IP, or `mwan3`/`ip rule` per-WAN
  routing tables — this is what lets MPTCP subflows leave on each WAN).
- DNS: route via the tunnel or via shadowsocks — not via an untrusted WAN
  resolver directly.

### Fail-open posture (required client behavior)

If the OCI endpoint or `bonding-vm` is unreachable, the router **must fall
back to direct gateway-group routing** (the normal dual-WAN load-balance/
failover group): LAN egress degrades to unbonded direct internet, never to
a full outage. Implement as: gateway-group tier 1 = tunnel default route,
tier 2 = direct WAN gateways, with tunnel-down detection
(`glorytun`/shadowsocks health check or route-metric flip on keepalive
loss). Bonded paths restore automatically when the endpoint returns.

## Verification / operations

levonk recipes live in `levonk/justfile` — from the repo root run
`just --justfile levonk/justfile <recipe>` (or `cd levonk && just <recipe>`,
or the `devbox run -- ansible-*-wanbonding` devbox.json scripts).

- `just --justfile levonk/justfile levonk-build-wanbonding` — build + push
  the arm64 image (amd64 Mac, `docker buildx`). Alternatively the generic
  root recipe: `just docker-build-push localnet-net-wanbonding`.
- `just --justfile levonk/justfile levonk-deploy-wanbonding` — provision +
  configure (manual approval required; check mode:
  `levonk-deploy-wanbonding-check`).
- `just --justfile levonk/justfile levonk-validate-wanbonding` — read-only
  host + guest checks (VM state, DHCP reservation, DNAT rules,
  `net.mptcp.enabled`, listeners, `glorytun show dev`, containers,
  nftables).
- Role-level health: `wanbonding_verify_health` + `--tags verify`.
- Snapshot before upgrades: `sudo virsh snapshot-create-as bonding-vm`.

## Consequences

- ✅ True single-flow bonding across Spectrum + T-Mobile via MPTCP.
- ✅ WAN-loss session survival for TCP (remaining subflows carry on).
- ✅ Clean security boundary; WAN-facing daemons never touch the OCI host.
- ✅ Rollback is a qcow2 snapshot.
- ⚠️ All LAN traffic hairpins through OCI — adds region RTT and consumes
  the 10 TB/mo egress budget; quota monitoring required.
- ⚠️ Asymmetric-jitter reordering limits real-world gain on the cable+5G
  pair (see table above).
- ⚠️ OCI security-list ingress is a manual step — drift possible if rules
  are edited outside this ADR's documented set.
