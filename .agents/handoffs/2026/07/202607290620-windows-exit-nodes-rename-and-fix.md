# Windows Exit Nodes: Rename Services, Fix Arch, Fix Tailscale Registration

**Date**: 2026-07-29
**Session**: Deploy NordVPN and Tor exit nodes on Windows Docker host (dtop202311)
**Status**: Blocked — host unreachable + three issues to fix before redeployment

## Current State

### Completed
- **Roles created**: `vpn-nordvpn-windows` and `vpn-tor-windows` (need renaming — see Issue 1)
- **Playbook created**: `deploy-windows-exit-nodes.yml`
- **Justfile recipes**: `ansible-deploy-windows-exit-nodes` added
- **Infrastructure variables**: ports, networks, services added to shared + levonk YAML files
- **Vault updated**: Real NordVPN OpenVPN credentials pulled from running OCI container and stored in vault
- **Images built and pushed**: `localnet-base-alpine` and `localnet-proxy-tor` (both arm64 AND amd64)
- **NordVPN container deployed**: `nordvpn-windows` running on dtop202311
- **Tor container deployed**: `tor-exit-windows` deployed but crash-looping (wrong arch)
- **Tailscale containers deployed**: `tailscale-nordvpn-windows` and `tailscale-tor-windows` deployed

### Blocking Issues

1. **Host unreachable**: The Tailscale containers disrupted the Windows host's Tailscale networking. `dtop202311` shows `rx 0` in tailscale status — no packets getting through. The host needs physical access to stop the containers and restart its Tailscale service.

2. **Three issues identified by user** (must fix before redeployment):
   - Issue 1: Services named with `-windows` suffix (violates naming convention)
   - Issue 2: Tor image built for arm64, host is x86/amd64
   - Issue 3: NordVPN Tailscale container not registering as exit node

## Project Overview

### Objective
Deploy NordVPN and Tor exit nodes on the Windows Docker host (dtop202311) for the levonk client, mirroring the existing OCI exit nodes but adapted for Windows Docker Desktop.

### Current Status
Deployment was attempted and partially succeeded, but the host is now unreachable and three issues must be fixed.

## Key Decisions Made

- **Windows Docker pattern**: Use `ansible.builtin.shell/command` with `delegate_to: localhost` and `DOCKER_HOST: ssh://` — `community.docker` modules don't work on Windows (Unix-only `grp` import)
- **NordVPN auth**: Use OpenVPN credentials (not WireGuard token) — matches the working OCI container
- **Vault credentials**: Pulled real OpenVPN creds from the running OCI NordVPN container and stored in vault (were previously empty)

## Technical Context

### Stack/Tools
- Ansible with `delegate_to: localhost` + `DOCKER_HOST: ssh://` pattern
- Docker containers: gluetun (NordVPN), tailscale/tailscale (exit node), localnet-proxy-tor (Tor)
- Tailscale for exit node advertisement
- Windows Docker Desktop on dtop202311 (amd64/x86_64)

### Important Files
- `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/tasks/main.yml` — NordVPN role (needs renaming)
- `shared/active/02-config/ansible/roles/vpn-tor-windows/tasks/main.yml` — Tor role (needs renaming)
- `shared/active/02-config/ansible/playbooks/deploy-windows-exit-nodes.yml` — Playbook
- `shared/active/02-config/ansible/infrastructure/networks.yml` — Network definitions (lines 144-158 have wrong `-windows` names)
- `shared/active/02-config/ansible/infrastructure/ports.yml` — Port definitions
- `shared/active/02-config/ansible/infrastructure/services.yml` — Service definitions
- `levonk/active/02-config/ansible/inventories/group_vars/windows_docker_hosts.yml` — Host vars
- `shared/active/08-docs/adr/adr-20260625001-multi-exit-node-architecture.md` — **THE ADR with the naming convention**

### Environment Notes
- Windows host dtop202311 is currently UNREACHABLE via Tailscale SSH
- The host's Tailscale daemon was disrupted by the containerized Tailscale exit nodes
- Physical access required to recover the host

## Required Tasks

### 0. Recover the Windows Host (BLOCKING — requires physical access)
**Problem**: dtop202311 is unreachable via Tailscale. The `tailscale-nordvpn-windows` and `tailscale-tor-windows` containers disrupted the host's Tailscale networking.
**Recovery Steps** (on the physical Windows host):
```powershell
docker stop tailscale-nordvpn-windows tailscale-tor-windows nordvpn-windows tor-exit-windows
docker rm tailscale-nordvpn-windows tailscale-tor-windows nordvpn-windows tor-exit-windows
Restart-Service Tailscale
```

### 1. Rename All Services to Remove `-windows` Suffix
**Problem**: Services, containers, networks, volumes, and roles are named with `-windows` suffix. Per the ADR and AGENTS.md naming convention, the `-windows` suffix is NOT used. The Freenet and Wazuh services on Windows Docker Desktop use standard names (`freenet-network`, `wazuh-network`) without any `-windows` suffix.

**Reference**: `shared/active/08-docs/adr/adr-20260625001-multi-exit-node-architecture.md`
- ADR specifies: `vpn-network` (172.28.0.0/16), `tor-network` (172.30.0.0/16)
- ADR specifies Tailscale hostnames: `oci-vpn-server-nordvpn`, `oci-vpn-server-tor`
- Container names: `nordvpn`, `tailscale-nordvpn`, `tor-exit`, `tailscale-tor`
- For Windows host, Tailscale hostnames should follow the pattern: `dtop202311-vpn-server-nordvpn`, `dtop202311-vpn-server-tor`

**Files to Check**:
- `shared/active/02-config/ansible/infrastructure/networks.yml` (lines 144-158 — rename `vpn-network-windows` → `vpn-network`, `tor-network-windows` → `tor-network`)
- `shared/active/02-config/ansible/infrastructure/ports.yml` (rename variables)
- `shared/active/02-config/ansible/infrastructure/services.yml` (rename services)
- `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/` (rename to `vpn-nordvpn` and merge with existing, OR rename to something else — but NOT `-windows`)
- `shared/active/02-config/ansible/roles/vpn-tor-windows/` (same)
- `levonk/active/02-config/ansible/inventories/group_vars/windows_docker_hosts.yml` (rename all variables)
- `shared/active/02-config/ansible/playbooks/deploy-windows-exit-nodes.yml` (update references)

**Renames needed**:
- Networks: `vpn-network-windows` → `vpn-network`, `tor-network-windows` → `tor-network`
- Containers: `nordvpn-windows` → `nordvpn`, `tor-exit-windows` → `tor-exit`
- Tailscale containers: `tailscale-nordvpn-windows` → `tailscale-nordvpn`, `tailscale-tor-windows` → `tailscale-tor`
- Volumes: `localnet-nordvpn-windows-*` → `localnet-nordvpn-*`, `localnet-tor-windows-*` → `localnet-tor-*`
- Tailscale hostnames: `dtop202311-vpn` → `dtop202311-vpn-server-nordvpn`, `dtop202311-tor` → `dtop202311-vpn-server-tor`
- Variables: `vpn_nordvpn_windows_*` → `vpn_nordvpn_*`, `vpn_tor_windows_*` → `vpn_tor_*` (or use host-specific suffix)
- Roles: `vpn-nordvpn-windows` → merge into `vpn-nordvpn` (with Windows conditionals), `vpn-tor-windows` → merge into `vpn-tor` (with Windows conditionals) OR rename to reflect the Docker connection method, not the OS

**Note on subnets**: Docker networks are local to each host. Using `vpn-network` (172.28 on OCI, 172.40 on Windows) with the same name on different hosts is fine — they're isolated. But the subnets should be different to avoid confusion when debugging across hosts. Keep 172.40.0.0/16 for the Windows vpn-network and 172.41.0.0/16 for the Windows tor-network.

### 2. Fix Tor Image Architecture (arm64 → amd64)
**Problem**: The Tor image was built for `linux/arm64` but the Windows host (dtop202311) is `linux/amd64/v4`. The container shows `exec format error` in logs.
**Status**: The amd64 image was already built and pushed to the registry (`100.90.22.85:5000/localnet-proxy-tor:latest` — amd64 digest). But it hasn't been loaded on the Windows host yet because the host is unreachable.
**Fix**:
- After host recovery: `docker save 100.90.22.85:5000/localnet-proxy-tor:latest | gzip | DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" docker load`
- OR: Fix the insecure registry config on Windows Docker Desktop so `docker pull` works from the HTTP registry
- The build script (`scripts/build-and-push-images.sh`) defaults to `PLATFORM=linux/arm64` (for OCI). Need to either:
  - Build multi-arch images (`--platform linux/amd64,linux/arm64`)
  - OR build separately for each target host
  - Reference: `shared/active/08-docs/adr/adr-20260709001-container-build-strategy-mixed-arch.md` (mixed-arch build strategy ADR)

### 3. Fix NordVPN Tailscale Container Registration
**Problem**: The `tailscale-nordvpn-windows` container is not registering as a node on the Tailscale network, let alone asking for approval to be an exit node in the management UI.
**Investigation Needed**:
- Check if the Tailscale auth key is valid (not expired — keys expire after 90 days, last updated 2026-06-27)
- Check the container logs: `docker logs tailscale-nordvpn-windows --tail 50`
- The container may be failing to start because:
  a. The `sh -c "..."` command with embedded authkey has quoting issues
  b. The container can't reach Tailscale coordination servers (DNS/network issue inside Docker on Windows)
  c. The `--device /dev/net/tun:/dev/net/tun` doesn't work on Windows Docker Desktop (no /dev/net/tun)
  d. The `--cap-add NET_ADMIN` may not be sufficient on Windows Docker Desktop
  e. The `--sysctl net.ipv4.ip_forward=1` may not work on Windows Docker Desktop
- Compare with the working OCI Tailscale container to see what's different
- The OCI Tailscale container uses `TS_AUTHKEY` env var and the tailscale/tailscale image's built-in entrypoint — NOT a custom `sh -c` command. The Windows role should do the same.

**Files to Check**:
- `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/tasks/main.yml` (lines ~220-260 — Tailscale container deployment)
- The working OCI Tailscale container: `ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@100.90.22.85 "sudo docker inspect tailscale-nordvpn"`
- Tailscale admin UI: https://login.tailscale.com/admin/machines

## Next Steps (Priority Order)

1. **Recover the Windows host** (physical access required — stop containers, restart Tailscale service)
2. **Rename all services** to remove `-windows` suffix (Issue 1 — see task above for full rename list)
3. **Fix Tor image architecture** — load the amd64 image on the Windows host (Issue 2)
4. **Fix Tailscale container registration** — investigate why the container isn't registering, compare with working OCI container (Issue 3)
5. **Redeploy** with corrected names and fixed images
6. **Verify** — check that both exit nodes appear in Tailscale admin UI as exit nodes, check that Tor SOCKS proxy works, check that NordVPN proxy works

## Success Criteria

- ✅ No service, container, network, volume, or role name contains `-windows` suffix
- ✅ Network names match the ADR: `vpn-network` and `tor-network`
- ✅ Tailscale hostnames follow the pattern: `dtop202311-vpn-server-nordvpn` and `dtop202311-vpn-server-tor`
- ✅ Tor container runs without `exec format error` (amd64 image)
- ✅ Both Tailscale exit node containers register in the Tailscale admin UI
- ✅ Both exit nodes advertise as exit nodes in the Tailscale management UI
- ✅ NordVPN SOCKS proxy accessible at dtop202311:1081
- ✅ Tor SOCKS proxy accessible at dtop202311:9051
- ✅ Windows host dtop202311 remains reachable via Tailscale after deployment

## Open Questions/Blockers

- **Should the existing `vpn-nordvpn` and `vpn-tor` roles be extended with Windows conditionals, or should separate roles be kept?** — The existing roles use `community.docker` which doesn't work on Windows. Options: (a) add `when: ansible_os_family != "Windows"` conditionals and Windows-specific tasks in the same role, (b) keep separate roles but name them by connection method (e.g., `vpn-nordvpn-ssh`), (c) use a different pattern entirely.
- **Windows Docker Desktop insecure registry**: The `~/.docker/daemon.json` has `insecure-registries` configured but Docker Desktop doesn't read it. Need to configure via Docker Desktop settings API or use `docker save/load` workaround.
- **Tailscale on Windows Docker Desktop**: Does `/dev/net/tun` exist on Windows Docker Desktop? Does `NET_ADMIN` capability work? Need to verify the Tailscale container can actually create a TUN interface.

## Do Not

- Do NOT name services with `-windows` suffix — use the standard naming convention from the ADR
- Do NOT use `community.docker` modules on Windows Docker hosts — they fail due to Unix-only `grp` import
- Do NOT deploy Tailscale containers before verifying they won't disrupt the host's Tailscale daemon
- Do NOT build images for arm64 only when targeting amd64 hosts — use multi-arch builds or build per-target
- Do NOT use `no_log: true` on tasks that are failing — it hides the error and makes debugging impossible

## Suggested Skills

- **handoff** — This document itself; use to continue this work in a fresh session
- **git-repository-management** — After all fixes are applied, organize and commit the changes

## Additional Context

- **Project**: levonk/infrahub — Ansible infrastructure for levonk network
- **ADR Compliance**: `adr-20260625001-multi-exit-node-architecture.md` defines the exit node naming convention
- **ADR Compliance**: `adr-20260709001-container-build-strategy-mixed-arch.md` defines multi-arch build strategy
- **Git Workflow**: Commit all renames and fixes as a single coherent change after verification
- **Vault**: NordVPN OpenVPN credentials were updated in the vault during this session (pulled from running OCI container)
- **Tailscale Auth Key**: Last updated 2026-06-27, expires after 90 days (valid until ~2026-09-25)

## Files Modified This Session

1. `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/tasks/main.yml` — NordVPN Windows role
2. `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/defaults/main.yml` — NordVPN Windows defaults
3. `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/handlers/main.yml` — NordVPN Windows handlers
4. `shared/active/02-config/ansible/roles/vpn-nordvpn-windows/meta/main.yml` — NordVPN Windows meta
5. `shared/active/02-config/ansible/roles/vpn-tor-windows/tasks/main.yml` — Tor Windows role
6. `shared/active/02-config/ansible/roles/vpn-tor-windows/defaults/main.yml` — Tor Windows defaults
7. `shared/active/02-config/ansible/roles/vpn-tor-windows/handlers/main.yml` — Tor Windows handlers
8. `shared/active/02-config/ansible/roles/vpn-tor-windows/meta/main.yml` — Tor Windows meta
9. `shared/active/02-config/ansible/playbooks/deploy-windows-exit-nodes.yml` — Deployment playbook
10. `shared/active/02-config/ansible/infrastructure/networks.yml` — Network definitions (lines 144-158, need renaming)
11. `shared/active/02-config/ansible/infrastructure/ports.yml` — Port definitions
12. `shared/active/02-config/ansible/infrastructure/services.yml` — Service definitions
13. `levonk/active/02-config/ansible/inventories/group_vars/windows_docker_hosts.yml` — Host variables
14. `justfile` — Added `ansible-deploy-windows-exit-nodes` recipe
15. `devbox.json` — Added aliases
16. `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` — Updated NordVPN OpenVPN credentials
