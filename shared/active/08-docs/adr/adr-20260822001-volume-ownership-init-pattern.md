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

### Standard pattern: two-phase volume init with verification

Every Ansible role that deploys a container with `--user <non-root-uid>` and a
writable Docker volume MUST include a **two-phase volume initialization** before
the service container starts:

1. **Phase 1 — Fix ownership**: Run a throwaway `alpine` container that mounts
   the volume, `chown`s it to the target UID:GID, and exits.

2. **Phase 2 — Verify ownership**: Run a **second** throwaway `alpine` container
   that mounts the same volume, checks that the ownership actually matches the
   expected UID:GID, and exits non-zero if it doesn't. This catches cases where
   the chown silently failed (e.g., Docker Desktop volume driver quirks, race
   conditions, overlay filesystem issues).

### Why two phases (chown + verify)?

During the Hister deployment, the chown task ran successfully (`rc=0`) but the
volume ownership did not change. The Ansible task reported success because the
`docker run` command exited 0, but the actual filesystem inside the volume was
still root-owned. This is a known class of issue with Docker Desktop's volume
driver on Windows — the `chown` command runs inside the container's namespace,
but the volume's metadata may be managed by a different layer (virtiofs, 9p, or
the WSL2 filesystem bridge) that doesn't propagate ownership changes
deterministically.

A verification step that re-mounts the volume in a fresh container and checks
the actual ownership catches this class of silent failure. Without it, the
playbook reports success, the service container starts, and the crash loop
begins — exactly what happened with Hister.

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
# Two-phase: chown + verify. Runs before the service container starts.
# ============================================================================

# Phase 1: Fix ownership
- name: "Fix {{ service_name }} volume ownership (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm
    -v {{ service_data_volume }}:/data
    alpine sh -c 'chown -R {{ service_uid }}:{{ service_gid }} /data && chmod {{ service_mode | default("755") }} /data'
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  changed_when: false
  tags: ["deploy", "volume"]

# Phase 2: Verify ownership actually stuck
- name: "Verify {{ service_name }} volume ownership (UID {{ service_uid }})"
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

#### Phase 1 — `docker run --rm -v <volume>:/data alpine sh -c 'chown ...'`

| Component | Purpose |
|-----------|---------|
| `docker run --rm` | Create a temporary container, auto-remove it when the command exits. No container name, no restart policy, no network — it's a one-shot tool. |
| `-v <volume>:/data` | Mount the Docker volume at `/data` inside the throwaway container. This is the same volume that the service container will mount later. Changes to `/data` persist in the volume after the throwaway container exits. |
| `alpine` | Use the Alpine Linux image (~7MB). It's already cached on every host, starts in under 1 second, and has `chown`/`chmod` built in. |
| `sh -c 'chown -R 1000:1000 /data'` | Recursively change ownership of everything in the volume to UID 1000, GID 1000. The `-R` flag means "recursive" — all files and subdirectories. This is needed because the volume may already contain files from a previous run (e.g., a failed first start that wrote some files as root before crashing). |
| `chmod 755 /data` | Set the directory permissions to `rwxr-xr-x` (owner can read/write/execute, group and others can read/execute). This is the standard directory permission for service data. Some services may need `700` (e.g., databases with sensitive data) — override via `service_mode` variable. |
| `DOCKER_HOST: "{{ service_docker_host }}"` | For Windows Docker hosts, this is `ssh://ansible@dtop202311.tale-grouper.ts.net`. The Docker CLI runs on the Ansible control machine (localhost) but connects to the remote Docker daemon via SSH. This is the standard pattern for Windows Docker hosts in this repo (see `AGENTS.md` → "Windows Docker modules are broken"). |
| `delegate_to: localhost` | Run this task on the Ansible control machine, not on the target host. Combined with `DOCKER_HOST`, the Docker CLI runs locally but operates on the remote Docker daemon. |
| `changed_when: false` | This task is idempotent — running it on an already-correct volume changes nothing. Marking it as "not changed" keeps `ansible-playbook` output clean and prevents handlers from triggering unnecessarily. |

#### Phase 2 — `docker run --rm -v <volume>:/data alpine sh -c 'test "$(stat -c %u /data)" = "1000" ...'`

| Component | Purpose |
|-----------|---------|
| `stat -c %u /data` | Print the numeric UID of the `/data` directory (the volume root). `%u` = UID, `%g` = GID. We use numeric IDs because container usernames don't map between images (alpine's `root` is UID 0, same as the service image's user, but the names may differ). |
| `test "$(stat -c %u /data)" = "1000"` | Compare the actual UID to the expected UID. `test` exits 0 (success) if they match, exits 1 (failure) if they don't. |
| `&& test "$(stat -c %g /data)" = "1000"` | Also check the GID. The `&&` means "only run this if the previous test passed". If either check fails, the overall command exits non-zero. |
| `register: volume_ownership_check` | Save the command result (including exit code) to a variable for the `failed_when` check. |
| `failed_when: volume_ownership_check.rc != 0` | Fail the Ansible task if the verification command exited non-zero. This stops the playbook before the service container starts, preventing a crash loop. |

### Why the verify step is critical

Without verification, the following failure modes are invisible:

1. **Docker Desktop volume driver quirk**: The `chown` command runs inside the
   container's Linux namespace, but Docker Desktop on Windows uses a filesystem
   bridge (virtiofs or 9p) between the WSL2 VM and the Windows host. In some
   cases, ownership changes inside the container don't persist to the volume's
   backing store. The `chown` exits 0, but a subsequent `stat` shows the old
   ownership. This is what happened during the Hister deployment.

2. **Race condition with crash-looping container**: If a previous container is
   still running and holding a write lock on the volume, the `chown` may appear
   to succeed but not take effect. The verify step runs in a fresh container
   after the old container has been stopped.

3. **Overlay filesystem issues**: Some Docker storage drivers (overlay2,
   devicemapper) have edge cases where ownership changes on the upper layer
   don't reflect in the volume's merged view. A fresh container mount gives a
   clean view.

4. **Wrong volume name**: If the volume name in the chown task doesn't match the
   volume name in the service container's `-v` flag (e.g., due to a variable
   typo), the chown runs on a different volume and the service container still
   sees root ownership. The verify step catches this because it uses the same
   variable.

### Task ordering within the role

The volume init pair MUST run in this order:

```
1. Ensure volume exists       (docker volume inspect || docker volume create)
2. Fix volume ownership       (docker run --rm alpine chown)     ← Phase 1
3. Verify volume ownership    (docker run --rm alpine stat/test) ← Phase 2
4. Pull service image         (docker pull)
5. Stop existing container    (docker rm -f || true)
6. Deploy service container   (docker run -d ...)
7. Wait for health            (docker inspect --format ...Health.Status)
```

The chown MUST run after the volume exists but before the service container
starts. The verify MUST run immediately after the chown. If the verify fails,
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
TASK [search-hister : Verify Hister volume ownership (UID 1000)] ***************
fatal: [dtop202311 -> localhost]: FAILED! => {"cmd": "...", "rc": 1, "stdout": ""}
```

This means the `chown` ran but the ownership didn't stick. Do NOT proceed with
the service container deployment. Follow these steps:

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
# Exit codes: 0 = success, 1 = parameter error, 2 = chown failed, 3 = verify failed

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

# --- Phase 2: verify (built into the same script) ---
VERIFY_UID=$(stat -c %u "$DATA_DIR")
VERIFY_GID=$(stat -c %g "$DATA_DIR")

if [ "$VERIFY_UID" = "$UID_TARGET" ] && [ "$VERIFY_GID" = "$GID_TARGET" ]; then
    echo "OK: Volume ownership verified: ${VERIFY_UID}:${VERIFY_GID}"
    exit 0
else
    echo "ERROR: Verification failed!" >&2
    echo "  Expected: ${UID_TARGET}:${GID_TARGET}" >&2
    echo "  Actual:   ${VERIFY_UID}:${VERIFY_GID}" >&2
    echo "" >&2
    echo "This indicates the Docker volume driver did not persist the ownership" >&2
    echo "change. This is a known issue with Docker Desktop on Windows (WSL2" >&2
    echo "volume driver). See ADR-20260822001 for recovery procedures." >&2
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

Once built and pushed, the Ansible task pair simplifies to:

```yaml
# Phase 1+2 combined (init-volume.sh does chown + verify internally)
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
```

Or, if you prefer the two-task pattern (chown and verify as separate tasks for
clearer Ansible output):

```yaml
# Phase 1: chown
- name: "Fix {{ service_name }} volume ownership (UID {{ service_uid }})"
  ansible.builtin.command: >-
    docker run --rm --entrypoint /usr/local/bin/init-volume
    -v {{ service_data_volume }}:/data
    {{ local_registry | default('') }}localnet-volume-init:latest
    {{ service_uid }} {{ service_gid }} {{ service_mode | default('755') }}
  environment:
    DOCKER_HOST: "{{ service_docker_host }}"
  delegate_to: localhost
  changed_when: false
  tags: ["deploy", "volume"]

# Phase 2: verify (separate container, fresh mount)
- name: "Verify {{ service_name }} volume ownership (UID {{ service_uid }})"
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
| Error handling | `chown` failure may be masked by `&&` chaining | Explicit exit codes (1=param, 2=chown, 3=verify) |
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
