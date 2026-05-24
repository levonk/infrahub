# Chronyd fails to start: "Could not open /var/run/chrony/chronyd.pid: Permission denied"

## Summary
Chronyd in the custom NTP container failed to start because it couldn't write the PID file under `/var/run/chrony/chronyd.pid`. The issue was caused by `/run` being ephemeral in containers; the directory created during build was lost at runtime, and strict permissions prevented chronyd from creating it.

## Symptoms
- Container restarts repeatedly; healthcheck unhealthy
- Logs show:
  - `Fatal error : Could not open /var/run/chrony/chronyd.pid : Permission denied`
  - After initial fix attempts: `Fatal error : Not superuser`

## Root Cause
- `/run` (symlink for `/var/run`) is recreated on every container start. Directories/files made during image build are not guaranteed to exist at runtime.
- Our Dockerfile created `/run/chrony` at build time and set `750` perms, but the directory didn’t exist at runtime; chronyd (non-root) couldn't create/write the PID file.
- Chronyd also needs privileges to bind to UDP/TCP port `123`. Running without appropriate capabilities results in `Not superuser` when attempting privileged operations.

## Resolution
Implemented a runtime-safe startup and capability setup:

1. Entrypoint script creates runtime directories on every start:
   - Ensure `/run/chrony`, `/var/run/chrony`, and `/var/lib/chrony` exist
   - Attempt to set restrictive perms when possible (non-fatal on failure)
2. Start chronyd as root but with minimal capabilities granted via compose:
   - Compose grants: `SYS_TIME`, `NET_BIND_SERVICE`, `SETUID`, `SETGID` (and `DAC_OVERRIDE` comment left for clarity)
   - This allows binding to port 123 and time adjustments without running fully privileged

### Files Updated
- `services/ntp/chronyd/docker/Dockerfile.chronyd`
  - Adds `/entrypoint.sh` that ensures runtime dirs exist
  - Runs `ENTRYPOINT ["/entrypoint.sh"]` and `CMD ["-d", "-x", "-s"]`
  - Starts chronyd from entrypoint with correct privileges
- `services/ntp/docker-compose.ntp.yml`
  - `cap_add` retains minimal required caps (`SYS_TIME`, `NET_BIND_SERVICE`, `SETUID`, `SETGID`)

## Verify
- Rebuild and restart just the chronyd service:
  ```bash
  docker compose -f apps/active/devops/localnet/docker-compose.yml build chronyd && \
  docker compose -f apps/active/devops/localnet/docker-compose.yml up -d chronyd
  ```
- Run the NTP test suite:
  ```bash
  bash apps/active/devops/localnet/tests/ntp-accuracy-test.sh
  ```
- Expected:
  - Container `running` and `healthy`
  - Chronyd responsive (`chronyc tracking` works)
  - Host ports show mappings for UDP/TCP 123 and 1123

## Notes & Security
- Runtime-dir creation belongs in entrypoint scripts for services that write to `/run`. Build-time creation is insufficient.
- Capabilities keep privileges minimal; do not use `--privileged`.
- Keep `security_opt: no-new-privileges:true` in compose.
- Healthcheck remains `chronyc tracking` to ensure control-plane responsiveness.

## Troubleshooting Checklist
- If PID file error persists:
  - `docker compose logs chronyd | sed -n '1,120p'`
  - Exec into the container and inspect perms:
    ```bash
    docker compose exec chronyd sh -lc 'ls -ld /run /run/chrony /var/run/chrony && id && which chronyd && chronyd -v'
    ```
- If `Not superuser` appears:
  - Confirm compose `cap_add` includes `NET_BIND_SERVICE` and `SYS_TIME`
  - Ensure entrypoint actually starts `chronyd` (not daemonized by system scripts)
