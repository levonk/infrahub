---
workflow: "Update Host Packages Across All Infrahub Clients (macOS, Linux, Windows)"
slug: "infrahub-host-update-all"
description: "Audit and update OS-level packages on every managed host — nixpkgs/nix-darwin and Homebrew on macOS, distro packages on Linux, winget on Windows — honoring a >=2-day release-age policy where the ecosystem exposes dates, with git checkpoint tags, per-OS deploy, and health verification. Container images are covered separately by infrahub-update-all; this workflow covers everything else on the hosts."
use: "When the user asks to update host packages, update nixpkgs/Homebrew/distro/winget packages across the fleet, refresh flake inputs or devbox locks, or perform periodic host maintenance. Run infrahub-update-all first or alongside for container images."
date:
  created: "2026-11-18"
see-also:
  - file: "infrahub-update-all.md"
    relationship: "sibling"
    description: "Container image audit/update workflow. Run BOTH for a full fleet refresh — this workflow skips Docker images entirely."
  - skill: "ansible"
    relationship: "implementation"
    description: "Playbook and ad-hoc command patterns for Linux/Windows host updates."
  - skill: "git-repository-management"
    relationship: "implementation"
    description: "Commit workflow for flake.lock / devbox.lock changes across infrahub and client submodules."
  - file: "infrahub-git.md"
    relationship: "sibling"
    description: "Git workflow for infrahub and client submodules. Run after this workflow to commit lockfile changes."
  - file: "nix-darwin-local-validation.md"
    relationship: "reference"
    description: "shared/active/08-docs/runbooks/nix-darwin-local-validation.md — darwin-rebuild verification and rollback."
---

# Workflow: Update Host Packages Across All Infrahub Clients

Update OS-level packages on every managed host: nixpkgs + Homebrew on macOS,
distro packages on Linux, winget on Windows. Companion to
`infrahub-update-all.md`, which covers container images — **this workflow
does not touch Docker containers**.

## Prerequisites

1. Read the root [`AGENTS.md`](../../AGENTS.md) — devbox usage rules, vault
   handoff policy, submodule rules.
2. Read [`shared/active/02-config/ansible/AGENTS.md`](../../shared/active/02-config/ansible/AGENTS.md).
3. Read [`levonk/AGENTS.md`](../../levonk/AGENTS.md) — submodule workflow.
4. All shell interaction with tools MUST use:
   `cd ~/p/gh/levonk/infrahub && devbox run -- <command>`
5. Vault password file: `~/.ansible/vault_password`
6. SSH key for OCI server: `~/.ssh/lzkmbp2016-micro-oracle`

## Policy: Release Age Filter (>= 2 days)

**Prefer package versions released at least 2 days ago.** Enforcement varies
by ecosystem — apply the strictest mechanism each one offers:

| Ecosystem | Date source | Enforcement |
|-----------|-------------|-------------|
| nixpkgs (flake inputs) | Commit date on `nixpkgs-unstable` (GitHub API) | Pin flake input to newest commit with committer date <= today-2d |
| nix-darwin, treehouse, herdr inputs | Commit date on their default branches | Same pinning approach per input |
| devbox (nixpkgs pin in devbox.lock) | `devbox update` respects `minimumReleaseAge` if configured; otherwise pin nixpkgs ref | Check `devbox.json`/`devbox.lock` for a dated ref |
| Homebrew casks/formulae | **No publish-date API** | Cannot age-gate. Either accept latest on activation, or hold brew-managed updates by NOT triggering `darwin-rebuild` activation this run |
| Linux distro packages (apt/dnf) | Distro repos carry no per-package release dates | Rely on `unattended-upgrades`/`dnf-automatic` (already enabled) for security updates; full upgrades are best-effort — prefer `apt-get -s upgrade` review before applying |
| Windows winget | **No publish-date API** | Cannot age-gate. Review `winget upgrade` list and skip anything released "today" only if the user flags it |

**When an ecosystem cannot enforce the age filter, say so explicitly in the
audit report** and let the user decide per-host whether to proceed.

## Policy: Git Checkpoint and Rollback Tags

Same mechanism as `infrahub-update-all`: create pre-update and post-update
tags in both the `infrahub` parent repo and the `levonk` submodule so lockfile
and config changes can be rolled back.

- **Pre-update tag**: Phase 0, before any flake/lock edits.
- **Post-update tag**: Phase 5, after deploy + verification + commit.

```bash
cd ~/p/gh/levonk/infrahub
cd levonk
git tag -a "tags/updates/$(date -u +%Y/%m/%d)/host-update-pre" \
  -m "Pre-update checkpoint: host package update workflow"
cd ..
git tag -a "tags/updates/$(date -u +%Y/%m/%d)/host-update-pre" \
  -m "Pre-update checkpoint: host package update workflow"
```

Rollback uses `git-rollback.sh` from the `git-repository-management` skill —
see `infrahub-update-all.md` for the full procedure. For nix-darwin hosts,
rollback additionally means re-running `darwin-rebuild switch --rollback`
or switching to the previous generation.

## Policy: Secret Redaction

Same rules as `infrahub-update-all.md`: never copy secret values into audit
reports, handoffs, or commits. Package managers occasionally print env vars or
registry credentials in verbose output — filter `PASSWORD|PASS|SECRET|TOKEN|
KEY|CREDENTIAL|AUTH` patterns before recording anything.

## Phase 0: Pre-Update Git Checkpoint

Identical to `infrahub-update-all.md` Phase 0:

1. Check `git status --porcelain` in BOTH `~/p/gh/levonk/infrahub` and
   `levonk/` submodule.
2. If dirty: ask user to commit/stash, or commit as an approved checkpoint,
   or abort. Never mix user changes with update changes.
3. Create the pre-update tags shown above.
4. Record both tag names.

## Phase 1: Enumerate Hosts by OS

`[fork]` Build the host inventory from Ansible inventories:

```bash
cd ~/p/gh/levonk/infrahub

# macOS fleet (nix-darwin + Homebrew)
devbox run -- ansible-inventory \
  -i levonk/active/02-config/ansible/inventories/macos-hosts.yml \
  --list-hosts

# Linux cloud servers
devbox run -- ansible-inventory \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  --list-hosts

# Windows docker hosts
devbox run -- ansible-inventory \
  -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  --list-hosts

# Local/LAN hosts (if in scope)
devbox run -- ansible-inventory \
  -i shared/active/02-config/ansible/inventories/localnet.yml \
  --list-hosts
```

Known groups (verify against live inventory — do not assume):

| Group | Inventory | Hosts (as of 2026-11) |
|-------|-----------|------------------------|
| `macos_hosts` | `levonk/.../macos-hosts.yml` | lzkmbp2016 (x86, control machine), lzkmbp2018 (x86), lzkmm2026 (arm64) |
| `cloud_servers` | `levonk/.../oci.yml` | oci-cloud-server (+ KVM guests) |
| `windows_docker_hosts` | `levonk/.../windows-docker.yml` | dtop202311 |
| `localnet_hosts` | `shared/.../localnet.yml` | localnet-primary |

## Phase 2: Audit Current vs Latest (per OS)

### 2a. macOS — nixpkgs flake inputs

The client flake is `levonk/active/02-config/nix/darwin/flake.nix`. Inputs
to audit: `nixpkgs` (nixpkgs-unstable), `nixpkgs-x86-darwin` (26.05-darwin),
`nix-darwin`, `nix-darwin-x86`, plus overlay inputs `nixpkgs-tailscale`,
`treehouse`, `herdr`.

1. Read current locked revisions and their dates from `flake.lock`:

```bash
cd ~/p/gh/levonk/infrahub/levonk/active/02-config/nix/darwin
# lastModified per input tells you how stale each pin is
python3 -c "import json; [print(k, v.get('lastModified','?')) for k,v in json.load(open('flake.lock'))['nodes'].items() if 'lastModified' in v]"
```

2. Find the newest `nixpkgs-unstable` commit at least 2 days old:

```bash
CUTOFF=$(date -u -v-2d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ)
curl -s "https://api.github.com/repos/NixOS/nixpkgs/commits?sha=nixpkgs-unstable&until=$CUTOFF&per_page=1" \
  | jq -r '.[0] | .sha + " " + .commit.committer.date'
```

Repeat per input branch (`nixpkgs-26.05-darwin`, nix-darwin default branch,
treehouse, herdr default branches).

### 2b. macOS — Homebrew

On each macOS host (or once — brew state is per-host, audit per host):

```bash
ssh -i ~/.ssh/lzkmbp2016-micro-oracle auser@<host> \
  "/opt/homebrew/bin/brew outdated --json=v2"   # arm64
# or /usr/local/bin/brew on x86
```

Record outdated formulae/casks. **Note in the report that brew has no
release-age data** — these will upgrade to latest on next activation.

### 2c. Linux — distro packages

Per Linux host:

```bash
# Debian/Ubuntu
devbox run -- ansible cloud_servers -m shell -a \
  "apt-get update -qq && apt list --upgradable 2>/dev/null" \
  --vault-password-file ~/.ansible/vault_password

# RHEL-family
devbox run -- ansible cloud_servers -m shell -a "dnf check-update" \
  --vault-password-file ~/.ansible/vault_password

# unattended-upgrades status (should already be enabled)
devbox run -- ansible cloud_servers -m shell -a \
  "systemctl is-enabled unattended-upgrades 2>/dev/null || systemctl is-enabled dnf-automatic 2>/dev/null" \
  --vault-password-file ~/.ansible/vault_password
```

### 2d. Windows — winget

Per Windows host over SSH (OpenSSH, inventory `windows-docker.yml`):

```bash
devbox run -- ansible windows_docker_hosts -m win_shell -a \
  "winget upgrade --include-unknown" \
  --vault-password-file ~/.ansible/vault_password
```

Also note Windows Update / PSWindowsUpdate as a manual step — do NOT
auto-install OS cumulative updates without user confirmation.

### 2e. devbox projects

Projects with `devbox.json` (this repo, dotfiles, others under `~/p/gh/levonk/`):

```bash
cd <project> && devbox update --dry-run 2>/dev/null || devbox update
```

`devbox update` bumps `devbox.json`/`devbox.lock` (nixpkgs pin). Check
whether the project pins a dated nixpkgs ref for age filtering.

### 2f. Generate Audit Report

Per host × package-manager, categorize:

1. **Up to date**
2. **Update available, age-filtered OK (>=2d)**
3. **Update available, too fresh (<2d)** — hold, record for follow-up
4. **Update available, age unverifiable** (brew, winget, apt/dnf) — flag for user decision

Present the report; get confirmation before Phase 3.

## Phase 3: Apply Updates per OS

### 3a. macOS — nixpkgs / nix-darwin

1. Edit `levonk/active/02-config/nix/darwin/flake.nix` input URLs to pin the
   age-approved revisions (e.g. `github:NixOS/nixpkgs/<sha>`), OR run
   `nix flake update` then verify `flake.lock` `lastModified` >= 2 days —
   if fresher, re-pin to the older approved rev.
2. Repeat for `shared/active/02-config/nix/darwin/flake.nix` if it declares
   the same inputs (it is the shared module library — check whether inputs
   live only in the client flake).
3. `cd levonk/active/02-config/nix/darwin && nix flake lock` (or `nix flake update`
   with `--override-input` for the approved revs) to regenerate `flake.lock`.
4. Deploy to each macOS host: sync the updated flake (git pull on host if
   the flake is cloned there, or re-run `configure-macos-host.yml` which
   handles nix-darwin activation), then `darwin-rebuild switch`.
   - `homebrew.onActivation.upgrade = true` means brew formulae/casks
     upgrade during the same activation — this is where brew updates land.
   - If the user chose to hold brew updates, do NOT run activation this run;
     apply nix-only changes via `darwin-rebuild build` + manual switch, or
     defer the whole macOS update.
5. Watch for the known failure modes in
   `nix-darwin-local-validation.md` (unfree packages, Homebrew service
   reload non-zero exits, packages not on PATH after switch).

### 3b. Linux — distro packages

Preferred: dry-run first, then apply.

```bash
# Preview
devbox run -- ansible cloud_servers -m shell -a "apt-get -s upgrade" \
  --vault-password-file ~/.ansible/vault_password

# Apply (Debian/Ubuntu)
devbox run -- ansible cloud_servers -m shell -a \
  "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" \
  --vault-password-file ~/.ansible/vault_password

# Apply (RHEL-family)
devbox run -- ansible cloud_servers -m shell -a "dnf upgrade -y" \
  --vault-password-file ~/.ansible/vault_password
```

**Kernel updates require a reboot** — schedule/confirm with the user; do
not reboot production hosts automatically. `unattended-upgrades` already
covers security updates continuously; this phase is for the remainder.

### 3c. Windows — winget

```bash
devbox run -- ansible windows_docker_hosts -m win_shell -a \
  "winget upgrade --all --silent --accept-package-agreements --accept-source-agreements" \
  --vault-password-file ~/.ansible/vault_password
```

Skip packages flagged too-fresh if the user asked for strict age gating.
Windows Update cumulative updates: list pending updates and ask the user —
reboot-required, do not auto-install.

### 3d. devbox projects

For each project: `devbox update`, review the `devbox.lock` diff, commit.

## Phase 4: Verify

Per OS:

- **macOS**: `darwin-rebuild status` shows new generation active;
  `brew outdated` returns empty (or only held-back items);
  `system_profiler SPInstallHistoryDataType` sanity; confirm
  `/run/current-system/sw/bin` tools work (`command -v treehouse herdr`).
- **Linux**: services healthy — `systemctl --failed` empty;
  `docker ps` unchanged (containers are update-all's job);
  `ansible cloud_servers -m ping`.
- **Windows**: `winget upgrade` returns nothing pending;
  Docker Desktop still running (`docker version` via named pipe).
- **All**: re-run the Phase 2 audit commands — "up to date" or
  "held back (<2d / unverifiable)" for everything remaining.

## Phase 5: Commit and Tag

1. Stage lockfile/config changes: `flake.lock`, `devbox.json`,
   `devbox.lock`, any flake.nix input edits. Submodule (`levonk`) first,
   then parent repo gitlink bump — per `infrahub-git.md`.
2. Run the secret scan on `git diff --cached` (same pattern as
   `infrahub-update-all.md`).
3. Commit with messages describing WHY (age-approved revs, held-back items).
4. Push submodule, then parent.
5. Create post-update tags (`host-update-post`) in both repos.
6. Re-run `git status` — tree must be clean.

## Phase 6: Report and Handoff

Produce an audit report covering:

- Per host × manager: what was updated (old → new), what was held back and why
- Age-filter violations accepted (brew/winget/apt items with no date data)
- Items needing follow-up: <2d releases to retry next run, local builds,
  kernel updates pending reboot, Windows Update pending
- Rollback tag names for both repos

If pre-existing issues surfaced (failed services, broken hosts), capture a
handoff via the `handoff` skill per `infrahub-update-all.md` Phase 6.

## Quick Reference

```bash
# macOS nixpkgs: newest nixpkgs-unstable commit >=2 days old
CUTOFF=$(date -u -v-2d +%Y-%m-%dT%H:%M:%SZ)
curl -s "https://api.github.com/repos/NixOS/nixpkgs/commits?sha=nixpkgs-unstable&until=$CUTOFF&per_page=1" | jq -r '.[0].sha'

# flake.lock freshness per input
python3 -c "import json; [print(k,v['lastModified']) for k,v in json.load(open('flake.lock'))['nodes'].items() if 'lastModified' in v]"

# brew outdated (arm64 / x86)
ssh auser@<mac> "/opt/homebrew/bin/brew outdated --json=v2"   # or /usr/local/bin/brew

# linux preview / apply
devbox run -- ansible cloud_servers -m shell -a "apt-get -s upgrade"
devbox run -- ansible cloud_servers -m shell -a "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

# windows
devbox run -- ansible windows_docker_hosts -m win_shell -a "winget upgrade --all --silent --accept-package-agreements --accept-source-agreements"
```
