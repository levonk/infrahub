# Handoff: Infrastructure fixes (certs, TraLa, images, agentmemory)

**Date:** 2026-06-30
**Branch:** master
**Last Commit:** 47ebb65 — fix: Let's Encrypt certs, TraLa icons, upstream images, build caching, agentmemory

## Goal

Fix multiple issues identified after the registry refactor: Let's Encrypt staging certs on aigate/airoute, TraLa icons not loading, envoy/privoxy/squid missing Dockerfiles, build script not caching, agentmemory not deployed.

## Completed

- [x] Let's Encrypt: removed stale `static/traefik.yml` (had staging caServer), deleted staging certs from acme.json, verified production certs issued for aigate.levonk.com & airoute.levonk.com
- [x] TraLa icons: added service overrides (litellm, omniroute, searxng, authelia, homepage → selfh.st icons), added router/entrypoint excludes, verified 6 services with icons and groups
- [x] envoy/privoxy/squid: switched roles to pull upstream Docker Hub images directly (no custom Dockerfiles needed)
- [x] Build caching: added context-hash tracking via docker labels, `--force` flag, fixed Dockerfile path doubling bug
- [x] agentmemory: fixed healthcheck duration format, fixed handler state, built+pushed+deployed, container running healthy
- [x] Cleaned up stale `/opt/traefik/config/static/` directory on server

## In Progress / Next Steps

- [x] **Disk space on OCI server RESOLVED** — The physical disk is 200G but the root LV was only 30G (XFS not grown to fill LV, and 82.9G VG space unallocated). Fixed with `xfs_growfs /` + `lvextend -l +100%FREE` + `xfs_growfs /`. Root filesystem is now 183G with 153G free.
- [ ] Commit and push the changes (committed locally, not pushed)
- [ ] Consider moving the Docker registry to a separate volume/host to free disk space on the OCI server
- [ ] The `localnet_network_subnet` variable is undefined in some playbooks — this is a pre-existing issue that causes a fatal error in the `common` role but doesn't block deployment (the roles that need it define their own networks)

## Key Decisions

- **envoy/privoxy/squid use upstream images**: The docker-compose file referenced Dockerfiles that don't exist. The compose file also specifies upstream images (`envoyproxy/envoy:v1.28-latest`, `ubuntu/squid:latest`, `vimagick/privoxy:latest`). Decision: use upstream images directly in Ansible roles, no custom Dockerfiles needed.
- **TraLa excludes use router names without `@file` suffix**: TraLa's wildcard matching works on router names without the provider suffix. `*-http` matches `trala-http@file` but NOT `trala-https@file`.
- **Build caching via context hash**: A SHA256 hash of all files in the build context is stored as a docker label (`ctxhash`). On subsequent runs, if the local image has the same hash, the build is skipped. This is simpler than checking registry digests and works even when the registry is unreachable.

## Dead Ends (Don't Repeat These)

- **`docker save | docker load` with multi-platform images**: Fails with "no space left on device" because the saved tarball includes all platforms. Must build with `--platform linux/arm64` and save the single-platform image.
- **TraLa exclude patterns with `@file` suffix**: `trala-https@file` in the exclude list does NOT work. TraLa matches on the router name without the provider suffix. Use `trala-https` instead.
- **Healthcheck durations as integers**: `community.docker.docker_container` rejects bare integers (e.g., `30`) for healthcheck intervals. Must use strings with unit suffixes (e.g., `"30s"`).
- **Handler `state: restarted`**: Not valid in current `community.docker` version. Use `state: started` with `restart: true`.

## Files Changed

- `justfile` — added `docker-build-push-all-force` target
- `scripts/build-and-push-images.sh` — build caching (context hash), `--force` flag, fixed Dockerfile path doubling bug, removed envoy/privoxy/squid TODO
- `shared/active/02-config/ansible/roles/agentmemory/defaults/main.yml` — healthcheck durations: int → string with unit
- `shared/active/02-config/ansible/roles/agentmemory/handlers/main.yml` — `state: restarted` → `state: started` + `restart: true`
- `shared/active/02-config/ansible/roles/dashboard-trala/templates/trala-configuration.yml.j2` — service overrides, excludes, selfhst_icon_url, manual TraLa entry
- `shared/active/02-config/ansible/roles/forward-proxy/tasks/envoy.yml` — pull from Docker Hub instead of local registry
- `shared/active/02-config/ansible/roles/forward-proxy/tasks/privoxy.yml` — pull from Docker Hub instead of local registry
- `shared/active/02-config/ansible/roles/forward-proxy/tasks/squid.yml` — pull from Docker Hub instead of local registry

## Current State

- **Tests:** N/A (Ansible roles, no test suite)
- **Lint:** not run
- **Build:** working (build-and-push-images.sh tested with agentmemory)
- **Manual verification:**
  - aigate.levonk.com: production Let's Encrypt cert (issuer CN=YR2) ✅
  - airoute.levonk.com: production Let's Encrypt cert (issuer CN=YR2) ✅
  - start.levonk.com: has link to start2.levonk.com ✅
  - start2.levonk.com (TraLa): 6 services with icons and groups ✅
  - agentmemory: container running, healthy ✅
  - headroom: container running, healthy ✅
  - omniroute: container running, healthy ✅
  - Disk: 155M free on 30G — critical

## Context for Next Session

The OCI server's 30G disk is the primary blocker for full deployment. All core services (Traefik, Authelia, LiteLLM, Langfuse, Headroom, OmniRoute, agentmemory, TraLa, Homepage) are running, but there's no room for additional images. The Docker registry was removed and redeployed multiple times to free space. The `localnet_network_subnet` variable error in the `common` role is pre-existing and non-blocking.

**Recommended first action:** Check `df -h /` on the OCI server. If disk is full, clean up with `docker system prune -af` and consider moving the registry to a separate volume.
