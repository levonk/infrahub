# devops-restoredrill

Deploys [restoredrill](https://github.com/ahmadpiran/restoredrill) — a PostgreSQL
backup restore verification tool. Proves your backups actually restore by
dumping each Postgres instance, restoring the dump into a throwaway container,
running checks, and writing a JSON evidence report.

## What This Role Does

For each database in `restoredrill_databases`:

1. **pg_dump** the running Postgres container → compressed backup file
2. **restoredrill** restores that backup into a throwaway Postgres container,
   runs tiered checks (prechecks, structural, read-path, RTO), and writes a
   JSON evidence report
3. **Rotate** old backups (keep N most recent)
4. **Prometheus textfile** metrics for alerting on drill staleness

This is a **scheduled job** (systemd timer), not a long-running service. No
port, no domain, no Traefik routing.

## Requirements

- Docker on the target host (restoredrill launches throwaway Postgres containers)
- The Postgres containers being verified must be running and reachable
- `go` (if using `go_install` method) or GitHub release binaries (if using `download`)

## Variables

See [`defaults/main.yml`](defaults/main.yml) for all variables. Key ones:

| Variable | Default | Description |
|----------|---------|-------------|
| `restoredrill_databases` | `[]` | List of database dicts to verify (see below) |
| `restoredrill_version` | `v0.1.0` | restoredrill version (pin it) |
| `restoredrill_timer_calendar` | `*-*-* 03:00:00` | systemd timer schedule |
| `restoredrill_backup_retention_count` | `7` | Keep N most recent backups per DB |
| `restoredrill_postgres_image` | `postgres:16-alpine` | Throwaway restore container image |

### Database Entry Schema

```yaml
restoredrill_databases:
  - name: paperclip           # unique identifier
    container: paperclip-postgres  # running Postgres container name
    db_name: paperclip         # database name
    db_user: paperclip         # pg_dump user
    # Optional:
    db_password: "{{ vault_paperclip_pg_password }}"  # if password auth
    min_tables: 5              # minimum user tables after restore
    rpo_target: "25h"          # max acceptable backup age
    rto_target: "30m"          # max acceptable restore duration
    row_counts:                # read-path checks
      - table: users
        min: 100
    queries:                   # SQL assertions (must return one boolean row)
      - name: "users have valid emails"
        sql: "SELECT NOT EXISTS (SELECT 1 FROM users WHERE email IS NULL)"
    verify_as_role: app_user   # run checks as this role (needs globals_source)
```

## Deployment

```bash
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-restoredrill.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Monitoring

The Prometheus textfile metric `restoredrill_last_run_timestamp_seconds` is
written to the node_exporter textfile collector directory. Alert on its age
to catch silently stopped drills:

```promql
# Alert if no successful drill in 48 hours
alert: RestoredrillStale
expr: time() - restoredrill_last_run_timestamp_seconds > 172800
```

## Evidence Reports

JSON reports are written to `{{ restoredrill_report_dir }}/` and contain:
- Backup timestamp, age, RPO/RTO status
- Restore duration
- All check results (pass/fail with reasons)
- Trigger metadata (scheduled vs manual, who triggered it)

These are designed to drop into SOC 2 / ISO 27001 / AWS FTR evidence packets.

## Limitations

- **PostgreSQL only** (restoredrill v0.1.0). MySQL, restic, pgBackRest on roadmap.
- **Ephemeral container model**: database must fit in a container on the host.
- **No PITR/WAL replay**: verifies pg_dump-level restores only.
- **v0.1.0 is early**: pin the version, don't track `latest`.

## See Also

- Research: `internal-docs/research/service/restoredrill/README.md`
- Upstream: https://github.com/ahmadpiran/restoredrill
