---
modeline: "vim: set ft=markdown:"
title: "ADR: Docker Volume Ownership Init Pattern for Non-Root Containers"
adr-id: "adr20260822001"
slug: "volume-ownership-init-pattern"
url: "https://github.com/levonk/infrahub/blob/main/shared/active/08-docs/adr/adr-20260822001-volume-ownership-init-pattern.md"
synopsis: "Mandate a two-phase volume initialization pattern (chown + verify) for every Docker volume attached to a non-root container, executed as an Ansible task before the service container starts. The chown runs in a throwaway alpine container, the verify runs in a second throwaway container that exits non-zero if ownership doesn't match. Future direction: a parameterized utility container built from localnet-base-alpine that accepts volume, uid, gid, and mode as arguments."
author: "https://github.com/levonk"
date-created: "2026-08-22"
date-updated: "2026-08-22"
date-review: "2027-02-22"
date-triggers: ["2026-11-22"]
version: "0.1.0"
status: "accepted"
aliases: ["ADR-20260822001"]
tags: [doc/architecture/adr, docker, volume, ownership, permissions, ansible, windows-docker, non-root, init-container, utility-container]
supersedes: []
superseded-by: []
related-to: ["container-build-strategy-mixed-arch", "infrastructure-consolidation", "sandboxed-cli-egress"]
scope:
  impact-scope: [ansible-roles, docker-volumes, windows-docker-hosts, oci-cloud-server, all-containerized-services-with-volumes]
  excluded-scope: [ephemeral-containers-without-volumes, read-only-volumes, bind-mounts-where-host-owns-permissions]
---

# Decision Record: Docker Volume Ownership Init Pattern for Non-Root Containers

**Filename:** `adr-20260822001-volume-ownership-init-pattern.md`

- belongs in `shared/active/08-docs/adr/` (existing repo convention)

---

## Context

### The problem

Docker volumes created by `docker volume create` (or implicitly by `docker run -v
<volume>:/path`) are owned by **root (UID 0, GID 0)** by default. This is true on
every Docker platform — Linux, Docker Desktop for Mac, and Docker Desktop for
Windows (WSL2 backend).

When a service container runs as a non-root user (e.g., `--user 1000:1000`, which
is the standard for this repo per the `localnet-base-alpine` `cuser` convention
with `PUID=1000`/`PGID=1000`), the container cannot write to the volume. The
first write attempt fails with `permission denied`, the process exits, Docker
restarts it, it fails again — a **crash loop**.

### Concrete incident

During the Hister deployment (2026-08-22), the `localnet-hister` container
crash-looped on first deploy:

```
Error! Failed to initialize config: failed to create secret key file:
  open /hister/data/.secret_key: permission denied
```

Hister runs as UID 1000 and writes `/hister/data/.secret_key`, `db.sqlite3`,
`index.db/`, and `rules.json` on first start. The volume
`localnet-hister-data-volume` was root-owned. The container could not write.

The same class of bug has been encountered and individually worked around in:

- **`security-wazuh`** — Wazuh dashboard volumes need `chown -R 1000:0` before
  the dashboard container starts (see
  `roles/security-wazuh/tasks/main.yml` lines 240-258)
- **`isolation-vm-containers`** — Volume directories created with explicit
  `owner`/`group` via `ansible.builtin.file` on the Linux host (see
  `roles/isolation-vm-containers/tasks/volumes.yml`), but this only works when
  Ansible has direct host access (Linux/OCI), not for Docker Desktop on Windows
  where volumes live inside the WSL2 VM

### Why this is systemic

| Factor | Effect |
|--------|--------|
| Docker volumes are root-owned by default | Every non-root container with a writable volume hits this |
| This repo standardizes on UID 1000 (`cuser`) | Every service using `localnet-base-alpine` or running `--user 1000:1000` is affected |
| Windows Docker Desktop volumes live inside WSL2 | You can't `chown` from the Windows host — you must mount the volume into a container |
| `community.docker` modules can't run on Windows | Ansible's `docker_volume` module imports `grp` (Unix-only), so Windows deployments use `docker run` via SSH-tunneled Docker CLI |
| Each role has been solving this independently | No standard pattern, no verification step, no reusable abstraction |

### What does NOT work

1. **`ansible.builtin.file` with `owner`/`group`** — Only works when Ansible has
   direct filesystem access to the volume's mountpoint. On Docker Desktop for
   Windows, the mountpoint is inside the WSL2 VM at
   `/var/lib/docker/volumes/<name>/_data`, which is not directly accessible from
   the Windows host or from the Ansible control machine.

2. **`docker volume create --opt`** — Docker's local driver does not support
   setting ownership at creation time. The `--opt` flag is for driver-specific
   options (e.g., `device`, `type`, `o` for NFS), not for `chown`.

3. **Running the service container as root** — Violates the repo's security
   policy (non-root execution, `--security-opt no-new-privileges:true`, capability
   dropping). See `shared/active/03-container/AGENTS.md` → "Security: Non-root
   execution, capability dropping, read-only filesystems".

4. **Docker `userns-remap`** — Docker Desktop for Windows does not support
   `userns-remap` (it's a Linux daemon feature requiring daemon.json
   configuration that Docker Desktop doesn't expose). Even on Linux where it is
   supported, it maps container UID 1000 to host UID 100000+ — the volume is still
   not owned by the mapped UID.

5. **Entrypoint scripts that self-fix permissions** — Some upstream images
   (e.g., Postgres, MySQL) start as root, `chown` the data directory, then
   `exec gosu <user>`. This only works if the container starts as root, which
   violates our security policy. Images that don't have this pattern (like
   Hister, which runs as UID 1000 from the start) cannot self-fix.

---

## Decision

### Standard pattern: three-phase volume init with layered verification

Every Ansible role that deploys a container with `--user <non-root-uid>` and a
writable Docker volume MUST include a **three-phase volume initialization**
before the service container starts:

1. **Phase 1 — Fix ownership + in-container verify**: Run a throwaway `alpine`
   container that mounts the volume, `chown`s it to the target UID:GID, and
   **immediately verifies** the ownership from within the same container's mount
   namespace. If the in-container verify fails, the chown itself didn't take
   effect even within the container's own view of the filesystem — this is a
   fundamentally different failure mode from a persistence failure (see
   diagnostic matrix below).

2. **Phase 2 — Fresh-container verify**: Run a **second** throwaway `alpine`
   container that mounts the same volume in a fresh mount namespace and checks
   that the ownership actually persisted. This catches cases where the chown
   appeared to succeed inside the first container but didn't propagate to the
   volume's backing store (Docker Desktop WSL2 volume driver quirks, overlay
   filesystem issues, virtiofs/9p bridge problems).

3. **Phase 3 — Service container starts**: Only if both verifications pass does
   the service container start. If either verification fails, the playbook stops
   with a diagnostic message indicating which phase failed and what that means.

### Why three phases (chown + in-container verify + fresh-container verify)?

During the Hister deployment, the chown task ran successfully (`rc=0`) but the
volume ownership did not change. The Ansible task reported success because the
`docker run` command exited 0, but the actual filesystem inside the volume was
still root-owned. This is a known class of issue with Docker Desktop's volume
driver on Windows — the `chown` command runs inside the container's namespace,
but the volume's metadata may be managed by a different layer (virtiofs, 9p, or
the WSL2 filesystem bridge) that doesn't propagate ownership changes
deterministically.

Splitting verification into two layers — one inside the chown container and one
in a fresh container — produces a **diagnostic matrix** that pinpoints exactly
where the failure occurred:

### Diagnostic matrix

| Phase 1 (chown) | Phase 1 (in-container verify) | Phase 2 (fresh-container verify) | Diagnosis | Action |
|------------------|-------------------------------|-----------------------------------|-----------|--------|
| `rc=0` | PASS | PASS | Everything worked | Proceed to service container |
| `rc=0` | PASS | **FAIL** | **Volume driver persistence failure** — chown took effect inside the container's mount namespace but didn't persist to the volume's backing store. This is the Docker Desktop WSL2 quirk. | See "Recovery: persistence failure" below — stop any crash-looping containers, re-run chown, or recreate the volume |
| `rc=0` | **FAIL** | (not reached) | **Chown ineffective within same namespace** — the chown command ran and exited 0, but `stat` inside the same container shows the old ownership. This suggests an overlay filesystem issue or a read-only mount that silently ignores ownership changes. | Check if the volume is mounted read-only, check Docker storage driver, check for overlay2 upper-layer corruption |
| `rc!=0` | (not reached) | (not reached) | **Chown command itself failed** — permission denied on the volume, volume doesn't exist, or filesystem error. | Check volume exists, check Docker daemon health, check disk space |

Without the in-container verify (Phase 1), the persistence failure
(Phase 1 PASS, Phase 2 FAIL) is indistinguishable from "chown ran but we don't
know if it worked" — which is exactly the blind spot that caused the Hister
crash loop. The in-container verify narrows the diagnosis: if it passes, we know
the chown worked *at the VFS level inside the container*; if the fresh-container
verify then fails, we know the problem is specifically in the volume driver's
persistence layer, not in the chown command itself.

### Why this matters for Docker image authors

The in-container verify also serves as a **signal to upstream Docker image
authors**: if an image starts as root, `chown`s its data directory, then drops
to a non-root user via `gosu`/`su-exec`, the chown and the subsequent write
happen in the same mount namespace — so a chown that works in-container will
work for the service. This is the **upstream-correct pattern** used by Postgres,
MySQL, Redis, and other mature images.

Images that skip this pattern and start directly as a non-root user (like
Hister, which runs as UID 1000 from `ENTRYPOINT`) cannot self-fix: they're
already non-root when they try to write, so they can't `chown` the volume. The
three-phase init pattern in this ADR is the **infrastructure-side workaround**
for images that don't implement the start-as-root-then-drop pattern.

**The diagnostic signal**: if Phase 1's in-container verify passes but Phase 2's
fresh-container verify fails, and the service container then crash-loops, this
is strong evidence that the image should be fixed upstream to start as root,
`chown` the data directory in its entrypoint, and then drop to the non-root user
— rather than relying on the infrastructure to pre-fix the volume. The ADR's
recovery documentation should advise filing an upstream issue with this
recommendation.

### Why alpine?

- **Size**: ~7MB, already cached on every Docker host in the fleet
- **Speed**: Starts in under 1 second
- **Universality**: Available on all architectures (x86_64, aarch64) per
  ADR-20260709001 (multi-arch fleet)
- **Sufficiency**: Has `sh`, `chown`, `chmod`, `ls`, `stat`, `test` — everything
  needed for volume init and verification
- **Consistency**: The existing `security-wazuh` role already uses this pattern
  with `alpine`

### Why not `localnet-base-alpine` (yet)?

The repo's standard base image `localnet-base-alpine` includes `cuser` (UID
1000), `curl`, `bash`, `su-exec`, `ca-certificates`, and an entrypoint script.
For a volume-init throwaway container, this is overkill — we only need `chown`
and `stat`, which plain `alpine` provides. Using plain `alpine` also avoids a
dependency on the local registry being available during volume init (which might
fail if the registry itself has a volume ownership problem — a chicken-and-egg
scenario).

**Future direction**: A parameterized utility container built from
`localnet-base-alpine` is proposed in the "Future Enhancement" section below.

---

## Implementation

### Standard Ansible task pair

Every role that deploys a non-root container with a writable volume MUST include
this task pair (adapt variable names to the role's convention):

```yaml
# ============================================================================
# Volume Ownership Init (ADR-20260822001)
# Three-phase: chown+in-container-verify, then fresh-container verify.
# Runs before the service container starts.
# ============================================================================

# Phase 1: Fix ownership AND verify within the same container's mount namespace.
# If the in-container verify fails, the chown itself didn't take effect even
# within the container's own VFS view — overlay/fs issue, not a persistence issue.
- name: "Fix {{ service_name }} volume ownership (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm
    -v {{ service_data_volume }}:/data
    alpine sh -c 'chown -R {{ service_uid }}:{{ service_gid }} /data
    && chmod {{ service_mode | default("755") }} /data
    && test "$(stat -c %u /data)" = "{{ service_uid }}"
    && test "$(stat -c %g /data)" = "{{ service_gid }}"'
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  changed_when: false
  tags: ["deploy", "volume"]

# Phase 2: Fresh-container verify — mount the volume in a NEW container and
# check that the ownership persisted to the volume's backing store.
# If Phase 1 passed but Phase 2 fails, it's a volume driver persistence failure
# (Docker Desktop WSL2 quirk) — see the diagnostic matrix in the ADR.
- name: "Verify {{ service_name }} volume ownership persisted (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm
    -v {{ service_data_volume }}:/data
    alpine sh -c 'test "$(stat -c %u /data)" = "{{ service_uid }}" && test "$(stat -c %g /data)" = "{{ service_gid }}"'
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  register: volume_ownership_check
  changed_when: false
  failed_when: volume_ownership_check.rc != 0
  tags: ["deploy", "volume"]
```

### What each part does

#### Phase 1 — `docker run --rm -v <volume>:/data alpine sh -c 'chown ... && test ...'`

| Component | Purpose |
|-----------|---------|
| `docker run --rm` | Create a temporary container, auto-remove it when the command exits. No container name, no restart policy, no network — it's a one-shot tool. |
| `-v <volume>:/data` | Mount the Docker volume at `/data` inside the throwaway container. This is the same volume that the service container will mount later. Changes to `/data` persist in the volume after the throwaway container exits. |
| `alpine` | Use the Alpine Linux image (~7MB). It's already cached on every host, starts in under 1 second, and has `chown`/`chmod` built in. |
| `chown -R 1000:1000 /data` | Recursively change ownership of everything in the volume to UID 1000, GID 1000. The `-R` flag means "recursive" — all files and subdirectories. This is needed because the volume may already contain files from a previous run (e.g., a failed first start that wrote some files as root before crashing). |
| `chmod 755 /data` | Set the directory permissions to `rwxr-xr-x` (owner can read/write/execute, group and others can read/execute). This is the standard directory permission for service data. Some services may need `700` (e.g., databases with sensitive data) — override via `service_mode` variable. |
| `test "$(stat -c %u /data)" = "1000"` | **In-container verify**: immediately after chown, check that the UID of `/data` is actually 1000 *within this container's mount namespace*. If this fails, the chown command itself didn't take effect at the VFS level — this is an overlay/filesystem issue, not a persistence issue. The `&&` chaining means if `chown` fails, `test` doesn't run; if `chown` succeeds but `test` fails, the overall command exits non-zero. |
| `test "$(stat -c %g /data)" = "1000"` | Also verify the GID within the same container. |
| `DOCKER_HOST: "{{ service_docker_host }}"` | For Windows Docker hosts, this is `ssh://ansible@dtop202311.tale-grouper.ts.net`. The Docker CLI runs on the Ansible control machine (localhost) but connects to the remote Docker daemon via SSH. This is the standard pattern for Windows Docker hosts in this repo (see `AGENTS.md` → "Windows Docker modules are broken"). |
| `delegate_to: localhost` | Run this task on the Ansible control machine, not on the target host. Combined with `DOCKER_HOST`, the Docker CLI runs locally but operates on the remote Docker daemon. |
| `changed_when: false` | This task is idempotent — running it on an already-correct volume changes nothing. Marking it as "not changed" keeps `ansible-playbook` output clean and prevents handlers from triggering unnecessarily. |

#### Phase 2 — `docker run --rm -v <volume>:/data alpine sh -c 'test "$(stat -c %u /data)" = "1000" ...'`

| Component | Purpose |
|-----------|---------|
| `docker run --rm` | A **fresh** container — new mount namespace, new process. This is critical: the volume is re-mounted from the Docker volume store, so `stat` sees whatever actually persisted to the backing store, not what the Phase 1 container's VFS cache showed. |
| `stat -c %u /data` | Print the numeric UID of the `/data` directory (the volume root). `%u` = UID, `%g` = GID. We use numeric IDs because container usernames don't map between images (alpine's `root` is UID 0, same as the service image's user, but the names may differ). |
| `test "$(stat -c %u /data)" = "1000"` | Compare the actual UID to the expected UID. `test` exits 0 (success) if they match, exits 1 (failure) if they don't. |
| `&& test "$(stat -c %g /data)" = "1000"` | Also check the GID. The `&&` means "only run this if the previous test passed". If either check fails, the overall command exits non-zero. |
| `register: volume_ownership_check` | Save the command result (including exit code) to a variable for the `failed_when` check. |
| `failed_when: volume_ownership_check.rc != 0` | Fail the Ansible task if the verification command exited non-zero. This stops the playbook before the service container starts, preventing a crash loop. |

### Why both verification steps are critical

The two verification steps catch **different classes of failure**:

**Phase 1 in-container verify** catches:
- Overlay filesystem issues where `chown` exits 0 but the VFS layer doesn't
  reflect the change even within the same container
- Read-only mounts that silently ignore ownership changes
- Filesystem corruption at the overlay upper layer

**Phase 2 fresh-container verify** catches:
- **Docker Desktop volume driver persistence failure** — the `chown` took effect
  inside the Phase 1 container's mount namespace (Phase 1 verify passed), but
  didn't persist to the volume's backing store. When Phase 2's fresh container
  mounts the volume, it sees the old ownership. This is the Docker Desktop WSL2
  quirk that caused the Hister crash loop.
- Race conditions where a crash-looping container's writes interfere with the
  chown between Phase 1 and Phase 2
- Wrong volume name (if Phase 1 and Phase 2 use different variables due to a
  typo, Phase 2 will see the unfixed volume)

### Task ordering within the role

The volume init pair MUST run in this order:

```
1. Ensure volume exists       (docker volume inspect || docker volume create)
2. Fix + in-container verify  (docker run --rm alpine chown && test)  ← Phase 1
3. Fresh-container verify     (docker run --rm alpine stat/test)      ← Phase 2
4. Pull service image         (docker pull)
5. Stop existing container    (docker rm -f || true)
6. Deploy service container   (docker run -d ...)
7. Wait for health            (docker inspect --format ...Health.Status)
```

Phase 1 MUST run after the volume exists but before the service container
starts. Phase 2 MUST run immediately after Phase 1. If either phase fails,
the playbook stops before step 4, and the service container is never started —
no crash loop.

### When to apply this pattern

| Condition | Apply volume init? |
|-----------|-------------------|
| Container runs as non-root (`--user <uid>:<gid>` where uid != 0) and has a writable volume | **YES** — mandatory |
| Container runs as root | No — root can write to root-owned volumes |
| Container has a read-only volume (`:ro`) | No — no writes needed |
| Container uses a bind mount (not a Docker volume) | Use `ansible.builtin.file` on the host path instead (works on Linux/OCI; on Windows, use `win_file` or a container-based chown if the path is inside WSL2) |
| Container has no volumes | No — nothing to init |
| Volume already has correct ownership from a previous run | The chown is idempotent (`changed_when: false`), so running it again is harmless. The verify confirms it. |

---

## Existing implementations to update

The following roles already have a chown step but lack the verify step. They
should be updated to comply with this ADR:

| Role | File | Current state | Needed |
|------|------|---------------|--------|
| `security-wazuh` | `roles/security-wazuh/tasks/main.yml` lines 240-258 | chown only, no verify | Add verify task |
| `search-hister` | `roles/search-hister/tasks/deploy-windows.yml` lines 27-36 | chown only, no verify | Add verify task |
| `isolation-vm-containers` | `roles/isolation-vm-containers/tasks/volumes.yml` | `ansible.builtin.file` with owner/group (Linux only) | Add container-based chown+verify for Windows targets |

---

## Recovery procedures

### If the verify step fails

The playbook will stop with a message like:

```
TASK [search-hister : Verify Hister volume ownership persisted (UID 1000)] ******
fatal: [dtop202311 -> localhost]: FAILED! => {"cmd": "...", "rc": 1, "stdout": ""}
```

This means Phase 1 (chown + in-container verify) passed but Phase 2 (fresh-container
verify) failed. Per the diagnostic matrix, this is a **volume driver persistence
failure** — the chown took effect inside the Phase 1 container's mount namespace
but didn't persist to the volume's backing store. Do NOT proceed with the service
container deployment. Follow these steps:

#### If Phase 1 failed (in-container verify failed)

This is a different failure mode — the chown didn't take effect even within the
same container. This is NOT a persistence issue. Check:

1. Is the volume mounted read-only? (`docker run --rm -v <vol>:/data alpine mount | grep /data`)
2. Is the Docker storage driver corrupted? (`docker info | grep "Storage Driver"`)
3. Is the volume a remote/NFS volume with different ownership semantics?

#### If Phase 2 failed (fresh-container verify failed) — persistence failure

This is the Docker Desktop WSL2 volume driver quirk. The chown worked inside the
Phase 1 container but didn't persist to the volume's backing store.

#### Step 1: Check what the volume actually looks like

```bash
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine ls -la /data
```

Look at the UID and GID columns. If they show `0 0` (root), the chown didn't
take effect. If they show `65532 65532`, the volume was created by a container
that ran as the `nobody` user (Docker Desktop's default for some operations).

#### Step 2: Stop any container that might be using the volume

A crash-looping container can interfere with ownership changes:

```bash
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker rm -f <container-name>
```

#### Step 3: Run the chown manually with verbose output

```bash
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine \
  sh -c 'chown -Rv 1000:1000 /data && ls -la /data'
```

The `-v` flag on `chown` prints every file it changes. If you see the files
listed but `ls -la` still shows root ownership, the Docker volume driver is not
propagating the change — this is a Docker Desktop bug.

#### Step 4: If chown still doesn't stick, recreate the volume

This is destructive — it will lose any data in the volume. Only do this for
first-time deployments or if the data is disposable:

```bash
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker volume rm <volume-name>

DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker volume create <volume-name>

# Now run the chown+verify pair again
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine \
  sh -c 'chown -R 1000:1000 /data && chmod 755 /data'

DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine \
  sh -c 'test "$(stat -c %u /data)" = "1000" && echo OK || echo FAIL'
```

#### Step 5: If the volume has data that must be preserved

Use a tar-based backup and restore:

```bash
# Backup
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data -v /tmp:/backup alpine \
  tar czf /backup/volume-backup.tar.gz -C /data .

# Recreate volume
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker volume rm <volume-name> && \
  docker volume create <volume-name>

# Fix ownership
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine \
  sh -c 'chown -R 1000:1000 /data && chmod 755 /data'

# Restore data (preserves the 1000:1000 ownership)
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data -v /tmp:/backup alpine \
  sh -c 'tar xzf /backup/volume-backup.tar.gz -C /data && chown -R 1000:1000 /data'

# Verify
DOCKER_HOST="ssh://ansible@dtop202311.tale-grouper.ts.net" \
  docker run --rm -v <volume-name>:/data alpine \
  sh -c 'test "$(stat -c %u /data)" = "1000" && echo OK || echo FAIL'
```

---

## Future Enhancement: Parameterized Utility Container

### The problem with the current approach

The current pattern uses plain `alpine` with inline `sh -c '...'` scripts. This
works but has drawbacks:

1. **No error handling inside the container**: If `chown` fails on one file, it
   continues to others. The exit code reflects the last command, not all
   commands.
2. **No logging**: The chown runs silently. If it fails, there's no diagnostic
   output showing which files couldn't be changed.
3. **No parameter validation**: If someone passes an empty string as the UID,
   `chown -R :1000 /data` runs (changes only GID), which is not what was
   intended.
4. **Duplicated logic**: Every role copies the same `docker run --rm alpine
   sh -c '...'` pattern with slightly different inline scripts.

### Proposed: `localnet-volume-init` utility container

This repo already has the concept of base/tool containers:
`localnet-base-alpine`, `localnet-base-sidecar`, `localnet-base-dev`. These are
reusable base images that provide standard environments for different purposes.

A `localnet-volume-init` container would follow the same pattern — a small,
purpose-built utility container that does one thing: initialize Docker volume
ownership with verification.

#### Image design

```dockerfile
# shared/active/03-container/services/base/volume-init/Dockerfile.volume-init
FROM alpine:3.20

# Install only what's needed: chown, stat, find, tar (for backup/restore)
RUN apk add --no-cache findutils tar

# Copy the init script
COPY assets/static/volume-init/init-volume.sh /usr/local/bin/init-volume
COPY assets/static/volume-init/verify-volume.sh /usr/local/bin/verify-volume
RUN chmod +x /usr/local/bin/init-volume /usr/local/bin/verify-volume

# No USER directive — this container must run as root to chown
# The --rm flag ensures it's removed after each invocation
ENTRYPOINT ["/usr/local/bin/init-volume"]
```

#### `init-volume.sh` — the chown script with validation

```bash
#!/bin/sh
# init-volume.sh — fix Docker volume ownership with validation and logging
# Usage: docker run --rm -v <volume>:/data localnet-volume-init <uid> <gid> [mode]
# Exit codes: 0 = success, 1 = parameter error, 2 = chown failed,
#             3 = persistence verify failed, 4 = in-container verify failed

set -eu

DATA_DIR="${DATA_DIR:-/data}"
UID_TARGET="${1:-}"
GID_TARGET="${2:-}"
MODE="${3:-755}"

# --- Parameter validation ---
if [ -z "$UID_TARGET" ] || [ -z "$GID_TARGET" ]; then
    echo "ERROR: Usage: init-volume <uid> <gid> [mode]" >&2
    echo "  uid   — target UID (numeric, required)" >&2
    echo "  gid   — target GID (numeric, required)" >&2
    echo "  mode  — directory mode (default: 755)" >&2
    exit 1
fi

# Validate UID/GID are numeric
case "$UID_TARGET" in
    ''|*[!0-9]*) echo "ERROR: UID must be numeric, got: $UID_TARGET" >&2; exit 1 ;;
esac
case "$GID_TARGET" in
    ''|*[!0-9]*) echo "ERROR: GID must be numeric, got: $GID_TARGET" >&2; exit 1 ;;
esac

echo "INFO: Initializing volume at $DATA_DIR"
echo "INFO: Target ownership: ${UID_TARGET}:${GID_TARGET}"
echo "INFO: Target mode: ${MODE}"

# --- Show current state ---
CURRENT_UID=$(stat -c %u "$DATA_DIR")
CURRENT_GID=$(stat -c %g "$DATA_DIR")
echo "INFO: Current ownership: ${CURRENT_UID}:${CURRENT_GID}"

if [ "$CURRENT_UID" = "$UID_TARGET" ] && [ "$CURRENT_GID" = "$GID_TARGET" ]; then
    echo "INFO: Volume already has correct ownership — no changes needed"
    exit 0
fi

# --- Phase 1: chown ---
echo "INFO: Running chown -R ${UID_TARGET}:${GID_TARGET} ${DATA_DIR}"
if chown -R "${UID_TARGET}:${GID_TARGET}" "$DATA_DIR"; then
    echo "INFO: chown completed successfully"
else
    echo "ERROR: chown failed with exit code $?" >&2
    exit 2
fi

echo "INFO: Running chmod ${MODE} ${DATA_DIR}"
chmod "$MODE" "$DATA_DIR" || {
    echo "ERROR: chmod failed" >&2
    exit 2
}

# --- Phase 1.5: in-container verify (within this container's mount namespace) ---
# This catches overlay/fs issues where chown exits 0 but the VFS layer
# doesn't reflect the change even within the same container.
IN_CONTAINER_UID=$(stat -c %u "$DATA_DIR")
IN_CONTAINER_GID=$(stat -c %g "$DATA_DIR")

if [ "$IN_CONTAINER_UID" = "$UID_TARGET" ] && [ "$IN_CONTAINER_GID" = "$GID_TARGET" ]; then
    echo "INFO: In-container verify passed: ${IN_CONTAINER_UID}:${IN_CONTAINER_GID}"
else
    echo "ERROR: In-container verification failed!" >&2
    echo "  Expected: ${UID_TARGET}:${GID_TARGET}" >&2
    echo "  Actual:   ${IN_CONTAINER_UID}:${IN_CONTAINER_GID}" >&2
    echo "" >&2
    echo "The chown command exited 0 but stat inside the same container shows" >&2
    echo "the old ownership. This is NOT a persistence failure — it's an overlay" >&2
    echo "filesystem issue or a read-only mount. Check:" >&2
    echo "  1. Is the volume mounted read-only? (mount | grep /data)" >&2
    echo "  2. Is the Docker storage driver corrupted? (docker info)" >&2
    echo "  3. Is this a remote/NFS volume with different ownership semantics?" >&2
    exit 4
fi

# --- Phase 2: persistence verify (re-read from the volume's backing store) ---
# This catches Docker Desktop WSL2 volume driver quirks where the chown
# took effect inside the container's mount namespace but didn't persist
# to the volume's backing store. We re-stat the same path — in a fresh
# container this would be a fresh mount, but since this script runs in
# a single container, the caller should ALSO run verify-volume.sh in a
# separate container to get a true fresh-mount check.
PERSIST_UID=$(stat -c %u "$DATA_DIR")
PERSIST_GID=$(stat -c %g "$DATA_DIR")

if [ "$PERSIST_UID" = "$UID_TARGET" ] && [ "$PERSIST_GID" = "$GID_TARGET" ]; then
    echo "OK: Volume ownership verified: ${PERSIST_UID}:${PERSIST_GID}"
    echo "NOTE: For a true persistence check, also run verify-volume.sh in a" >&2
    echo "      separate container (fresh mount namespace). See ADR-20260822001." >&2
    exit 0
else
    echo "ERROR: Persistence verification failed!" >&2
    echo "  Expected: ${UID_TARGET}:${GID_TARGET}" >&2
    echo "  Actual:   ${PERSIST_UID}:${PERSIST_GID}" >&2
    echo "" >&2
    echo "In-container verify passed but re-stat shows different ownership." >&2
    echo "This may indicate a VFS cache issue. Run verify-volume.sh in a fresh" >&2
    echo "container to confirm. If the fresh container also fails, this is a" >&2
    echo "volume driver persistence failure (Docker Desktop WSL2 quirk)." >&2
    echo "See ADR-20260822001 for recovery procedures." >&2
    exit 3
fi
```

#### `verify-volume.sh` — standalone verification (for separate-task usage)

```bash
#!/bin/sh
# verify-volume.sh — verify Docker volume ownership matches expected values
# Usage: docker run --rm -v <volume>:/data localnet-volume-init verify <uid> <gid>
# Exit codes: 0 = ownership matches, 1 = parameter error, 2 = mismatch

set -eu

DATA_DIR="${DATA_DIR:-/data}"

if [ "${1:-}" = "verify" ]; then
    shift
fi

UID_EXPECTED="${1:-}"
GID_EXPECTED="${2:-}"

if [ -z "$UID_EXPECTED" ] || [ -z "$GID_EXPECTED" ]; then
    echo "ERROR: Usage: verify-volume verify <uid> <gid>" >&2
    exit 1
fi

ACTUAL_UID=$(stat -c %u "$DATA_DIR")
ACTUAL_GID=$(stat -c %g "$DATA_DIR")

if [ "$ACTUAL_UID" = "$UID_EXPECTED" ] && [ "$ACTUAL_GID" = "$GID_EXPECTED" ]; then
    echo "OK: Volume ownership verified: ${ACTUAL_UID}:${ACTUAL_GID}"
    exit 0
else
    echo "ERROR: Volume ownership mismatch!" >&2
    echo "  Expected: ${UID_EXPECTED}:${GID_EXPECTED}" >&2
    echo "  Actual:   ${ACTUAL_UID}:${ACTUAL_GID}" >&2
    exit 2
fi
```

#### Ansible usage with the utility container

Once built and pushed, the Ansible tasks simplify to:

```yaml
# Phase 1: chown + in-container verify (init-volume.sh does both internally)
# Exit code 4 = in-container verify failed (overlay/fs issue)
# Exit code 3 = persistence verify failed (volume driver quirk)
# Exit code 2 = chown itself failed
# Exit code 1 = parameter error
- name: "Fix {{ service_name }} volume ownership (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm
    -v {{ service_data_volume }}:/data
    {{ local_registry | default('') }}localnet-volume-init:latest
    {{ service_uid }} {{ service_gid }} {{ service_mode | default('755') }}
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  changed_when: false
  tags: ["deploy", "volume"]

# Phase 2: fresh-container verify (separate container, fresh mount namespace)
# This is the true persistence check — a fresh mount from the volume store.
# If Phase 1 passed but Phase 2 fails, it's a volume driver persistence failure.
- name: "Verify {{ service_name }} volume ownership persisted (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm --entrypoint /usr/local/bin/verify-volume
    -v {{ service_data_volume }}:/data
    {{ local_registry | default('') }}localnet-volume-init:latest
    verify {{ service_uid }} {{ service_gid }}
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  register: volume_ownership_check
  changed_when: false
  failed_when: volume_ownership_check.rc != 0
  tags: ["deploy", "volume"]
```

### Why a utility container is a good idea here

| Factor | Plain `alpine` (current) | `localnet-volume-init` (proposed) |
|--------|--------------------------|-----------------------------------|
| Parameter validation | None — bad UID silently does wrong thing | Validates numeric UID/GID, prints usage on error |
| Error handling | `chown` failure may be masked by `&&` chaining | Explicit exit codes (1=param, 2=chown, 3=persistence, 4=in-container) |
| Logging | Silent | Prints current state, target, and result |
| Verification | Separate manual task | Built into the init script, or standalone |
| Reusability | Each role copies inline `sh -c` scripts | One image, one entrypoint, arguments determine behavior |
| Consistency | Each role's inline script may differ slightly | All roles use the same validated script |
| Diagnostics on failure | `rc=1` with no context | Clear error messages with expected vs. actual values |
| Recovery guidance | None | Error message references ADR-20260822001 for recovery steps |
| Build dependency | None (alpine is public) | Requires building and pushing `localnet-volume-init` |

### When to build the utility container

The utility container is a **future enhancement**, not a blocking dependency.
The current `alpine` + inline script pattern is acceptable and is the
**mandated baseline** per this ADR. The utility container should be built when:

1. A third role needs volume init (justifying the abstraction)
2. The inline scripts start diverging (different chmod modes, different
   verification logic)
3. A Docker Desktop volume driver bug requires more sophisticated diagnostics
   than `test` can provide

Until then, the two-phase `alpine` pattern is the standard.

### Relationship to existing tool/container patterns in the repo

This repo already has several categories of reusable containers:

| Container | Purpose | Lifecycle |
|-----------|---------|-----------|
| `localnet-base-alpine` | Base image for services (includes `cuser`, `curl`, `bash`) | Long-running (services inherit from it) |
| `localnet-base-sidecar` | Base image for sidecar containers (Nix store sharing) | Long-running (sidecars run alongside services) |
| `localnet-base-dev` | Development environment container | Interactive (long-running, dev shell) |
| `localnet-base-kalinix` | Kali Linux-based security tooling | Long-running or interactive |
| `localnet-volume-init` (proposed) | Volume ownership initialization | Ephemeral (`--rm`, one-shot, exits immediately) |

The `localnet-volume-init` container is a new category: a **utility container**
— a one-shot, `--rm` container that performs a specific infrastructure task and
exits. This is the same lifecycle as the `alpine` containers used for config
seeding in `proxy_traefik_windows` (the `traefik-windows-config-seed` container
that copies config files into a volume). The difference is that
`localnet-volume-init` would be a reusable, parameterized image rather than a
one-off `alpine` invocation with inline commands.

---

## Consequences

### Positive

- **Eliminates a class of crash-loop bugs**: Every non-root container with a
  writable volume gets its ownership fixed before first start.
- **Catches silent failures**: The verify step detects Docker Desktop volume
  driver quirks that cause `chown` to appear successful but not persist.
- **Standardized pattern**: All roles follow the same two-phase structure,
  reducing per-role variation and bugs.
- **Clear failure mode**: When verification fails, the playbook stops with a
  diagnostic message and a reference to recovery procedures, rather than
  starting a crash-looping container.
- **Idempotent**: Running the playbook on an already-healthy volume changes
  nothing and reports success.

### Negative

- **Two extra `docker run` commands per volume**: Adds ~4 seconds to deployment
  time (2 seconds per `docker run` on Windows Docker Desktop via SSH). This is
  negligible compared to image pulls and container startup.
- **Alpine image must be cached**: If alpine is not present on the target host,
  it will be pulled (~7MB, ~5 seconds on a reasonable connection). This is a
  one-time cost per host.
- **Does not solve bind-mount ownership**: Bind mounts (host directories) have
  different ownership semantics. On Linux, `ansible.builtin.file` works. On
  Windows, the host directory's ownership is managed by Windows ACLs, not Unix
  permissions. This ADR covers Docker volumes only.

### Risks

- **Docker Desktop volume driver bugs may evolve**: The verify step catches
  current bugs, but future Docker Desktop versions may introduce new volume
  driver behaviors. The verify step is the safety net — if it fails, the
  playbook stops and the operator investigates.
- **Utility container build dependency (future)**: If the `localnet-volume-init`
  image is built and roles depend on it, a registry outage could block volume
  init. The current `alpine` pattern has no such dependency. Mitigation: keep
  the `alpine` fallback pattern documented in the role's README.

---

## Review Schedule

**Review Date:** 2027-02-22 (6 months from adoption)

**Review Triggers:**
- A third role needs volume init (evaluate building `localnet-volume-init`)
- Docker Desktop releases a version that changes volume driver behavior
- A volume init failure occurs that the verify step doesn't catch
- A role is found that deploys a non-root container with a writable volume but
  doesn't use this pattern (enforcement gap)

---

## References

- ADR-20260709001: Container Build Strategy for Mixed-Architecture Fleets
  (alpine must be multi-arch)
- ADR-20260625001: Infrastructure Consolidation Strategy (variable naming
  conventions for `service_uid`, `service_gid`, `service_data_volume`)
- ADR-202608051501: Sandboxed CLI Container Egress Control (precedent for
  ephemeral `--rm` utility containers)
- `shared/active/02-config/ansible/AGENTS.md` → "Windows Docker Volume Ownership
  (UID-mismatch pattern)" (operational documentation derived from this ADR)
- `shared/active/02-config/ansible/roles/security-wazuh/tasks/main.yml` lines
  240-258 (existing chown pattern, needs verify step added)
- `shared/active/02-config/ansible/roles/search-hister/tasks/deploy-windows.yml`
  lines 25-36 (existing chown pattern, needs verify step added)
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/volumes.yml`
  (Linux host-based ownership pattern, complementary for non-Windows targets)
- `shared/active/03-container/services/base/base-alpine/Dockerfile.base-alpine`
  (base image with `cuser` UID 1000 — the standard that makes this ADR necessary)
- AGENTS.md: Architectural Invariants (non-root execution, no-new-privileges)
- AGENTS.md: Host Mutation Policy (throwaway container carve-out — `--rm`
  utility containers are explicitly permitted)
