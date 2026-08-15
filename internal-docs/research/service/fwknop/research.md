# Research: fwknop (Single Packet Authorization for SSH)

## Service Overview

**fwknop** (FireWall KNock OPerator) implements Single Packet Authorization (SPA)
to hide services (primarily SSH) from port scanners. Instead of leaving port 22
open, the server only opens it temporarily after receiving a single encrypted,
HMAC-signed UDP packet from an authorized client.

- **Upstream**: https://www.cipherdyne.org/fwknop/
- **Source repo**: https://github.com/mrash/fwknop
- **Debian/Ubuntu package**: `fwknop-server` (server), `fwknop-client` (client)
- **Type**: Host-level security service (NOT a container) — installs via apt, manages UFW/iptables, runs as systemd service

## Reference Article

Michele Bologna's blog post (June 2026) is the primary reference:
https://www.michelebologna.net/2026/ssh-port-22-fwknop-single-packet-authorization/

Key points from the article:

1. **Problem**: Port 22 open to the internet = banner grabbing, log noise,
   zero-day exposure window. fail2ban + key-only auth helps but the port is
   still reachable.

2. **SPA flow**: Client sends one encrypted UDP packet → `fwknopd` validates
   it → inserts a temporary iptables rule opening port 22 for the client's
   source IP for a configurable window (120s default) → rule auto-removes.
   From a scanner's perspective, port 22 is filtered (no response).

3. **Crypto**: SPA packet is HMAC-SHA512 authenticated + encrypted. Contains
   timestamp + single-use sequence counter → replay attacks fail silently.

4. **Key generation**: `fwknop --key-gen` produces `KEY_BASE64` and
   `HMAC_KEY_BASE64`. One shared pair covers all hosts. Stored in Ansible
   vault as `vault_fwknop_spa_key` and `vault_fwknop_hmac_key`.

5. **Server deployment (Ansible)**:
   - Install `fwknop-server` via apt
   - Deploy `/etc/fwknop/fwknopd.conf` and `/etc/fwknop/access.conf` (0600, no_log)
   - Remove public SSH UFW rule (after fwknop is confirmed working)
   - Allow SPA UDP port through UFW
   - `fwknopd` inserts iptables rules directly, beneath UFW's management layer

6. **Client configuration** (`~/.fwknoprc`):
   - One `[default]` stanza with keys, digest type, ALLOW_IP resolve
   - One stanza per host with SPA_SERVER + SPA_SERVER_PORT
   - Can be managed by chezmoi (keys from Bitwarden or vault)

7. **SSH integration**: `ProxyCommand fwknop -n <host>; sleep 2; nc %h %p` in
   `~/.ssh/config` makes the knock transparent.

8. **Ansible integration**: `ansible_ssh_common_args` with ProxyCommand so
   post-deploy Ansible runs knock first. Initial provisioning uses plain SSH
   (fwknop not installed yet).

9. **Tailscale as parallel path**: `tailscale0` interface always permits SSH
   with no knock. Not a fallback — a separate access path. If fwknop locks out
   the public interface, any Tailscale device can still reach the machine.

## Alternatives Considered

### 1. Tailscale-only (no public SSH at all)
- **Pros**: Zero attack surface, no extra software, already deployed
- **Cons**: Single point of failure (Tailscale outage = no SSH), doesn't help
  if Tailscale auth key expires or tailnet is misconfigured
- **Verdict**: Already have Tailscale as parallel path. fwknop adds a
  non-Tailscale public access route that's still invisible to scanners.

### 2. Port knocking (knockd)
- **Pros**: Simple, lightweight
- **Cons**: Knock sequence travels in cleartext — replayable. No authentication,
  only obscurity. fwknop SPA solves this with crypto.
- **Verdict**: Rejected — fwknop is strictly better.

### 3. Non-standard SSH port (e.g., 2222)
- **Pros**: Trivial to implement, reduces automated scanner noise
- **Cons**: Security through obscurity. Determined scanners find it. Port 22
  is already hardened (key-only, fail2ban, ed25519-only).
- **Verdict**: Already have hardening. Doesn't make port invisible, just less
  obvious.

### 4. WireGuard-only SSH
- **Pros**: Strong crypto, no exposed SSH port
- **Cons**: Similar to Tailscale-only — single VPN failure = lockout. Already
  have Tailscale covering this role.
- **Verdict**: Redundant with existing Tailscale.

## Decision: fwknop SPA on oci-cloud-server

**Deploy fwknop-server to `oci-cloud-server` only.**

Rationale:
- It's the only host with a public IP that gets scanned
- Isolation VMs are behind NAT (192.168.100.0/24, 192.168.101.0/24), not
  reachable from the internet — fwknop on them is pointless
- Tailscale stays as the always-open parallel path (no knock needed)
- fail2ban stays as defense-in-depth (still useful if a knock succeeds but
  auth fails repeatedly)
- Shared key pair (one KEY_BASE64 + HMAC_KEY_BASE64) in Ansible vault

## Deployment Plan (infrahub-specific)

This is a **host-level security role**, not a container service. It follows
the pattern of `common-ssh-hardening` and `common-fail2ban`, not the container
deployment pattern (Phases 3-5 of infrahub-add-new-service.md don't apply).

### What applies from the implementation guide:
- Phase 1: Shared infrastructure schemas (ports.yml — SPA UDP port)
- Phase 2: Client infrastructure values (ports override)
- Phase 2f: Service catalog metadata (services.yml entry)
- Phase 4: Vault secrets (vault handoff for keys)

### What does NOT apply:
- Phase 3: Build pipeline (apt package, not a container image)
- Phase 5: Container role (this is a host-level apt+systemd role)
- Traefik routing (no web UI)
- Docker network/volume

### Custom phases for fwknop:
1. Create `common-fwknop-server` Ansible role (apt install, config templates,
   UFW management, systemd service)
2. Create `deploy-fwknop.yml` playbook
3. Vault handoff for `vault_fwknop_spa_key` + `vault_fwknop_hmac_key`
4. Client-side `~/.fwknoprc` via chezmoi in dotfiles repo
5. Wire `ansible_ssh_common_args` ProxyCommand (gated behind `fwknop_enabled`)
6. Deploy with port 22 STAYING OPEN initially
7. User tests SPA knock + SSH + Ansible
8. User confirms → close port 22 publicly via Ansible UFW rule removal
9. Verify port 22 is invisible to scanners

### Safety gates:
- Port 22 stays open until user explicitly confirms SPA works
- Tailscale interface always allows SSH (parallel path)
- `fwknop_enabled` flag defaults to false — must be explicitly set true
- UFW rule removal is a separate playbook task with its own tag
