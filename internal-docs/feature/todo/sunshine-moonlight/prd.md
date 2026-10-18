---
slug: sunshine-moonlight
title: Sunshine + Moonlight Game Streaming — Sunshine on Windows (native), Moonlight on macOS fleet
client: levonk
status: in-progress
created: 2026-10-17
tech-context: |
  ## Tech Context (Binding Constraint)
  - Config management: Ansible (roles under shared/active/02-config/ansible/roles/, playbooks under .../playbooks/)
  - Windows automation: ansible.windows.win_shell + winget (community.docker does NOT work on Windows targets — grp is Unix-only)
  - macOS fleet apps: nix-darwin homebrew.casks (shared/active/02-config/nix/darwin/modules/system/homebrew.nix) + Ansible homebrew_cask fallback (rustdesk-client pattern)
  - Test runner: ansible-playbook --syntax-check, --check mode; validate-*.yml playbooks
  - Linter: ansible-lint
  - Package env: devbox (CURRENTLY BROKEN — packer-1.15.3 nixpkgs build crash; use `nix shell nixpkgs#ansible -c <cmd>` until fixed)
  - Inventory: levonk/active/02-config/ansible/inventories/{windows-docker.yml,macos-hosts.yml}
  - Vault: ~/.ansible/vault_password + scripts/edit-vault.sh handoff — agent NEVER edits the vault
  Never use: docker compose, hardcoded IPs/ports (infra_* vars only), community.docker on Windows targets
---

# PRD: Sunshine + Moonlight Game Streaming

## Goal

Enable Moonlight game streaming from the Windows desktop `dtop202311` to the
macOS fleet (`lzkmbp2016`, `lzkmbp2018`, `lzkmm2026`):

1. **Sunshine** (game-stream host, https://github.com/LizardByte/Sunshine)
   installed **natively** on `dtop202311` (Windows + Docker Desktop host,
   `windows_docker_hosts` group) via winget + Ansible, with the Sunshine
   Windows service running, firewall rules in place, web UI reachable over
   Tailscale, and vault-managed web UI credentials.
2. **moonlight-qt** (client, https://github.com/moonlight-stream/moonlight-qt)
   installed on all `macos_hosts` via the nix-darwin homebrew cask
   (`moonlight`) with a thin Ansible role for targeted install + automated
   pairing against the Sunshine host.

## Decision Record (from user Q&A + research)

- **Native Windows install, NOT Docker.** Docker Desktop on Windows runs
  Linux containers — a Sunshine container could only stream a virtualized
  Linux desktop, not the Windows desktop, and cannot do Windows display
  capture or NVENC. User confirmed native install.
  Research: `internal-docs/research/service/sunshine/sunshine-docker-windows.md`
- **Deploy path A** — lint → test → deploy remotely → verify → hand off.
- **mDNS does not cross Tailscale** — Moonlight hosts are added manually by
  FQDN (`dtop202311.tale-grouper.ts.net`); pairing is PIN-based and can be
  automated via `moonlight pair --pin` + Sunshine `POST /api/pin` with
  web-UI basic-auth credentials.
  Research: `internal-docs/research/service/moonlight-qt/moonlight-macos.md`

## Architecture

```
 Macs (macos_hosts)                    dtop202311 (windows_docker_hosts)
 ┌──────────────────┐   Moonlight    ┌────────────────────────────────┐
 │ Moonlight.app    │ ──streams──→   │ Sunshine (native, winget)      │
 │ (brew cask       │   over         │  - sunshine service (auto)     │
 │  "moonlight")    │   Tailscale    │  - web UI :47990 HTTPS         │
 │                  │   FQDN         │  - GameStream :47984/47989/    │
 │ Pairing: PIN via │ ←──PIN────     │    48010 TCP, UDP 47998-48000/ │
 │ /api/pin or web  │                │    48010                       │
 │ UI :47990        │                │  - Firewall rules (installer   │
 └──────────────────┘                │    + role-verified)            │
                                     └────────────────────────────────┘
```

## Scope

### In scope

- `infra_port_stream_sunshine_*` vars in shared `ports.yml` (TCP 47984,
  47989, 47990, 48010; UDP 47998, 47999, 48000, 48002 reserved, 48010;
  UDP 5353 mDNS noted LAN-only, not opened).
- Shared Ansible role `media-sunshine` (Windows native): winget install,
  `sunshine.conf` template (incl. `origin_web_ui_allowed = wan` for
  Tailscale-routed web UI access), credentials via `sunshine --creds`
  from vault vars, Windows Firewall rule verification, service state.
- Playbooks `deploy-sunshine.yml` (windows_docker_hosts) and
  `validate-sunshine.yml` (service, ports, web UI reachability).
- Homebrew cask `moonlight` in shared nix-darwin `homebrew.nix`.
- Levonk nix-darwin module `modules/moonlight.nix` (QSettings defaults:
  `packetsize` for Tailscale MTU ~1280, video config) registered in the
  levonk darwin flake — mirrors `rustdesk-client.nix` pattern.
- Shared Ansible role `media-moonlight-client` (darwin): cask install
  fallback (rustdesk-client pattern), optional automated pairing
  (`moonlight pair --pin` + `POST /api/pin`) when vault creds exist,
  Local Network permission handoff note.
- Playbook `deploy-moonlight.yml` (macos_hosts).
- `services.yml` entries (both), levonk `justfile` deploy recipes,
  `devbox.json` script entries.
- Vault handoff: `vault_sunshine_web_username` /
  `vault_sunshine_web_password` via `scripts/edit-vault.sh`.

### Out of scope

- Dockerized Sunshine (rejected — see Decision Record).
- Traefik/Cloudflare DNS — no public domain; Tailscale-only access.
- GPU/driver config on dtop202311 (assumed working Windows desktop GPU).
- Moonlight pairing TCC/permission automation beyond what macOS allows
  (Local Network prompt is a one-time human click).

## Acceptance Gates

- `deploy-sunshine.yml` syntax-checks; role passes `ansible-lint`.
- Sunshine installed on dtop202311; `Get-Service` for the Sunshine
  service reports Running; the Sunshine port set is listening;
  `https://dtop202311.tale-grouper.ts.net:47990` answers (self-signed).
- `deploy-moonlight.yml` syntax-checks; Moonlight.app present at
  `/Applications/Moonlight.app` on all three Macs after rollout.
- All ports referenced via `infra_port_stream_sunshine_*` vars — zero
  hardcoded ports/IPs in tasks, templates, or playbooks.
- No secrets in `shared/` or plaintext; web UI creds only via vault.
- SERVICES.md regenerated for shared + levonk catalogs.

## File Map

| Area | Path |
|------|------|
| Shared ports | `shared/active/02-config/ansible/infrastructure/ports.yml` |
| Sunshine role | `shared/active/02-config/ansible/roles/media-sunshine/` |
| Playbooks | `shared/active/02-config/ansible/playbooks/{deploy,validate}-sunshine.yml`, `deploy-moonlight.yml` |
| Moonlight role | `shared/active/02-config/ansible/roles/media-moonlight-client/` |
| Catalog | `shared/active/02-config/ansible/infrastructure/services.yml` |
| macOS cask | `shared/active/02-config/nix/darwin/modules/system/homebrew.nix` |
| Levonk darwin | `levonk/active/02-config/nix/darwin/{flake.nix,modules/moonlight.nix}` |
| Levonk recipes | `levonk/justfile`, `devbox.json` script entries |
| Vault (handoff) | `levonk/.../group_vars/infrahub-levonk-all.vault.yml` via `scripts/edit-vault.sh` |

## Secrets

- `vault_sunshine_web_username`, `vault_sunshine_web_password` — Sunshine
  web UI admin + `/api/pin` pairing auth. Agent generates values; user
  adds via `scripts/edit-vault.sh`. Role defaults them to `''` and skips
  credential/pair tasks when unset (handoff path documented instead).
