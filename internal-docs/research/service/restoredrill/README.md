# Research: restoredrill (PostgreSQL Backup Restore Verification)

## Service Overview

**Upstream**: https://github.com/ahmadpiran/restoredrill
**Language**: Go (module `github.com/ahmadpiran/restoredrill`, Go 1.25)
**License**: MIT
**Version**: v0.1.0 (early days, per README)
**Dependencies**: `gopkg.in/yaml.v3 v3.0.1` only (per `go.mod`); external runtime
deps are Docker and, for S3 sources, the `aws` CLI

`restoredrill` is a CI-native CLI tool that **proves PostgreSQL backups actually
restore**. Its thesis is "untested backups aren't backups": instead of trusting
that a `pg_dump` archive on disk or in S3 is good, restoredrill fetches the
latest backup, restores it into a throwaway Postgres container, runs user-defined
checks against the restored data, and writes a JSON evidence report with
timestamps and restore duration.

It is explicitly **not** a backup tool. It assumes your backups are already being
made by something else (pg_dump cron, a managed snapshot, etc.) and concerns
itself only with proving they're recoverable, on a schedule your recovery policy
defines. The output is designed to drop straight into a SOC 2, ISO 27001, or AWS
Foundational Technical Review evidence packet.

It is **fail-closed by default**: a check that can't run counts as a failure,
not a skip, and a notification that fails to deliver is itself a finding that
exits non-zero.

## What It Checks

Checks run in tiers, all fail-closed:

1. **Prechecks** (before restore): backup file size floor, archive header
   readability (table of contents for `pg_dump_custom`; completion marker for
   `pg_dump_sql`), and RPO freshness (backup age vs. `rpo_target`).
2. **Structural** (after restore): restore completed, `min_tables` user tables
   present, sequence integrity (serial/identity sequences in sync with their
   column max — a class of bug that only surfaces on the first INSERT after a
   disaster).
3. **Read-path**: row counts per table, data freshness, and user-defined SQL
   assertions. Each assertion query must return exactly one row with a single
   boolean; an erroring check is a FAILURE, not a skip. This catches restores
   that exit 0 but are still lying until someone actually reads the data.
4. **RTO evidence**: measured restore duration checked against `rto_target` if
   set.
5. **Environment sanity**: the container must come up and accept connections,
   which also proves the recovery environment has enough room to work.

## Evidence Report

The JSON report is the product. Key design choices:

- **Every field is always present**, even when it doesn't apply, so auditors can
  copy reports into a spreadsheet without fields appearing/disappearing.
- **Timestamps** are literal `"YYYY-MM-DD HH:MM:SS UTC"` strings (not epoch or
  RFC3339) specifically to survive copy-paste into spreadsheets.
- **Accountability fields** (`triggered_by`, `triggered_by_user`,
  `pipeline_job_id`) use the same schema whether a scheduler or a person ran the
  drill; manual runs carry the same accountability as scheduled ones.
- **`backup_resolved_key`** records the actual file/object drilled, not just the
  configured source. For S3 prefix sources it picks the newest object *after*
  verifying it looks like the right format, so a checksum sidecar uploaded after
  the real backup can't win just by being newer.
- **`backup_candidates_considered`** lists every S3 prefix object considered, in
  order, and why any were skipped. Empty for non-prefix sources.
- **RPO/RTO fields**: `backup_timestamp`, `backup_age_seconds`,
  `rpo_target_seconds`, `rpo_met`, `restore_initiated_at`,
  `restore_completed_at`, `restore_duration_seconds`, `rto_target_seconds`,
  `rto_met`.
- **`validation_errors`**: every failed check as its own field with what failed
  and why.
- **`notify_errors`**: a broken Slack/webhook URL is a finding, not a silent
  no-op; the process exits non-zero even if the drill itself passed.

## Config Schema

Config is a single YAML file (`--config`). Two examples ship in the repo.

### Minimal quickstart (`examples/quickstart.yml`)

Point at a local dump file, require Docker, get a report. No S3, no CI:

```yaml
backup:
  source: ./backup.dump
  format: pg_dump_custom

postgres:
  image: postgres:16

checks:
  min_tables: 1

report:
  path: restoredrill-report.json
```

Run: `restoredrill --config quickstart.yml --trigger manual`

### Full example (`examples/restoredrill.yml`)

```yaml
backup:
  # Local path, file:// URL, or s3:// URL. An s3:// source ending in "/" is a
  # prefix: the newest object under it is drilled (requires the aws CLI),
  # verified by content when the format supports it (see s3_object_pattern).
  source: s3://my-backups/postgres/daily/
  # pg_dump_custom for pg_dump -Fc archives, pg_dump_sql for plain SQL dumps.
  format: pg_dump_custom
  # Glob to filter S3 prefix candidates (e.g. "*.dump"), so a checksum or
  # metadata sidecar can't be picked over the real backup. Optional for
  # pg_dump_custom (content is verified directly); required for pg_dump_sql
  # with a prefix source, since plain SQL has no content signature to check.
  # s3_object_pattern: "*.dump"
  # A `pg_dumpall --globals-only` file, restored before the main backup so
  # the roles/grants it references actually exist in the sandbox. Same
  # source forms as `source` above, but always an exact file: no prefix or
  # newest-object selection, since a globals dump is a single well-known
  # file you'd name explicitly. Setting this also makes the main restore
  # keep ownership and privileges instead of stripping them.
  # globals_source: s3://my-backups/postgres/globals.sql

postgres:
  # Match your production major version.
  image: postgres:16

sandbox:
  # never (default) | on-failure | always: keep the restored container
  # running for human inspection instead of tearing it down.
  keep: on-failure

checks:
  # --- prechecks (run before the restore) ---
  # Fail if the backup file is suspiciously small. Unset (0) gets a tiny
  # built-in default floor that only catches literally-empty files; set a
  # real threshold for your database, or -1 to disable the floor entirely.
  min_size_bytes: 1048576
  # Validate the dump's table of contents before restoring (default: true).
  # pg_dump_custom only: plain SQL dumps have no inspectable header, so
  # this precheck can't have an equivalent for pg_dump_sql.
  archive_integrity: true
  # RPO target: the backup being drilled must be no older than this,
  # measured from its own timestamp to drill start. Fails closed if the
  # timestamp can't be determined; also catches a backup cron that
  # silently died, leaving a stale file in place.
  rpo_target: 48h

  # --- structural ---
  # Fail if fewer than this many user tables exist after restore.
  min_tables: 5
  # Fail if any serial/identity sequence lags behind its column's max value
  # (broken sequences only surface on the first INSERT after a disaster).
  sequence_integrity: true
  # RTO target: the measured restore duration must be at or under this.
  # Optional; omit it if you don't want restore speed to gate pass/fail.
  rto_target: 30m

  # --- read-path ---
  # Run row_counts and queries checks as this role instead of the sandbox
  # superuser, so a grant that was never captured in the backup fails the
  # check the way it would fail a real application. Requires
  # backup.globals_source (the role has to exist in the sandbox first).
  # verify_as_role: app_user
  # Fail if these tables have fewer rows than expected.
  row_counts:
    - table: users
      min: 100
    - table: orders
      min: 1000
  # Your own assertions: each query must return exactly one row with a
  # single boolean value. A check that errors is a FAILURE, not a skip.
  queries:
    - name: orders reference valid users
      sql: "SELECT NOT EXISTS (SELECT 1 FROM orders o LEFT JOIN users u ON u.id = o.user_id WHERE u.id IS NULL)"
    - name: data is fresh (backup younger than 48h)
      sql: "SELECT max(created_at) > now() - interval '48 hours' FROM orders"

notify:
  # Full JSON report, POSTed after every drill.
  # webhook_url: https://example.com/hooks/restoredrill
  # Short text summary to a Slack incoming webhook.
  # slack_webhook_url: https://hooks.slack.com/services/T000/B000/XXXX

output:
  # node_exporter textfile-collector metrics. Alert on the age of
  # restoredrill_last_run_timestamp_seconds to catch silently stopped drills.
  # prometheus_textfile: /var/lib/node_exporter/textfile/restoredrill.prom

report:
  path: restoredrill-report.json
```

### Top-level keys

| Key | Purpose |
|-----|---------|
| `backup.source` | Local path, `file://` URL, or `s3://` URL (prefix or exact) |
| `backup.format` | `pg_dump_custom` (`-Fc`) or `pg_dump_sql` (plain SQL) |
| `backup.s3_object_pattern` | Glob to filter S3 prefix candidates; required for `pg_dump_sql` + prefix source |
| `backup.globals_source` | `pg_dumpall --globals-only` file restored before main backup; enables `verify_as_role` and keeps ownership/privileges |
| `postgres.image` | Postgres image for the throwaway container; match production major version |
| `sandbox.keep` | `never` (default) / `on-failure` / `always` — keep container for inspection |
| `checks.min_size_bytes` | Backup size floor; `0` = tiny built-in default, `-1` = disable |
| `checks.archive_integrity` | Validate TOC (`pg_dump_custom`) or completion marker (`pg_dump_sql`); default `true` |
| `checks.rpo_target` | Max acceptable backup age (e.g. `48h`); fails closed if timestamp undeterminable |
| `checks.min_tables` | Min user tables after restore |
| `checks.sequence_integrity` | Fail if serial/identity sequences lag column max; default behavior per config |
| `checks.rto_target` | Max acceptable restore duration (e.g. `30m`); optional |
| `checks.verify_as_role` | Run read-path checks as this role (requires `globals_source`) |
| `checks.row_counts` | List of `{table, min}` — fail if fewer rows than expected |
| `checks.queries` | List of `{name, sql}` — each must return one row, one boolean; error = FAILURE |
| `notify.webhook_url` | POST full JSON report after every drill |
| `notify.slack_webhook_url` | One-line PASS/FAIL summary with failed checks listed |
| `output.prometheus_textfile` | node_exporter textfile metrics path; alert on age of `restoredrill_last_run_timestamp_seconds` |
| `report.path` | Where the JSON evidence report is written |

## CLI Flags

From `action.yml` and the README:

- `--config <path>` — config file (default `restoredrill.yml`)
- `--trigger scheduled|manual` — how this drill was triggered
- `--triggered-by <who>` — who triggered it (recorded on report; matters for manual runs)

Exit code is non-zero on any check failure or notification failure.

## Backup Verification Pipeline

restoredrill sits at the **verification** stage of a backup pipeline. It is not
the backup tool and not the alerting tool — it bridges them with evidence.

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Backup tool  │ → │ Backup store │ → │ restoredrill │ → │ Evidence +   │
│ (pg_dump,    │   │ (local file  │   │ (fetches     │   │ alerts       │
│  managed     │   │  or S3)      │   │  latest,     │   │ (JSON report,│
│  snapshot)   │   │              │   │  restores    │   │  Prometheus, │
│              │   │              │   │  to throwaway│   │  Slack,      │
│              │   │              │   │  container,  │   │  webhook)    │
│              │   │              │   │  runs checks)│   │              │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

- **Backup tool** (out of scope): anything that produces a `pg_dump -Fc` archive
  or plain SQL dump — a cron job, a managed RDS snapshot export, a Supabase
  CLI dump, etc.
- **Backup store**: local file or S3 (prefix or exact object). restoredrill
  picks the newest qualifying object for prefix sources.
- **restoredrill**: fetches, restores into ephemeral Postgres container, runs
  tiered checks, emits JSON report.
- **Evidence/alerts**: JSON report (auditor artifact), Prometheus textfile
  metrics (alert on staleness of last run), Slack summary, generic webhook.

The pipeline is **pull-based from the backup store**: restoredrill never touches
production. It only reads the backup artifact and spins up its own isolated
container. This is what makes it safe to run on a schedule.

## Deployment Model

- **Distribution**: Go binary, `go install github.com/ahmadpiran/restoredrill/cmd/restoredrill@<version>`.
  Single static binary; only runtime dependency is YAML parsing (compiled in).
- **Runtime requirements on the host**:
  - **Docker** — restoredrill launches a throwaway Postgres container for each
    drill. The host (or CI runner) must have a working Docker daemon.
  - **`aws` CLI** — only required when `backup.source` is `s3://`.
- **Execution model**: a scheduled job (cron, systemd timer, GitHub Actions
  schedule, CI pipeline). restoredrill is a one-shot CLI: it runs one drill,
  writes one report, exits. It is not a daemon.
- **CI-native**: exit-code based, ships a GitHub Action (`action.yml`) and a
  reference workflow (`.github/workflows/restoredrill.yml`). The action installs
  restoredrill via `go install`, runs it, and uploads the report as an artifact.
- **Scheduling**: restoredrill itself does not schedule. The README explicitly
  notes that "scheduled mode" is on the roadmap; today you drive it with cron or
  a CI schedule. The reference GitHub workflow is left `workflow_dispatch`-only
  so copying it doesn't silently start firing against a non-existent config.

### GitHub Action (`action.yml`)

Composite action with inputs:

| Input | Default | Purpose |
|-------|---------|---------|
| `config` | `restoredrill.yml` | Path to config file |
| `version` | `latest` | restoredrill version (git tag or `latest`) |
| `trigger` | `scheduled` | `scheduled` or `manual` |
| `triggered-by` | (empty) | Who triggered it (recorded on report) |
| `report-path` | `restoredrill-report.json` | Must match `report.path` in config |
| `report-artifact-name` | `restoredrill-report` | Artifact name; empty skips upload |

Output: `report-path` (path to the JSON evidence report).

The action sets up Go, configures `GOPRIVATE` for the (currently private) module,
installs via `go install`, runs restoredrill, and uploads the report with
`if: always()` so the artifact is captured even on failure.

### Reference workflow (`.github/workflows/restoredrill.yml`)

`workflow_dispatch`-only by default (no `schedule:`), with a `triggered_by`
input. The README instructs users to add `schedule: - cron: '...'` once pointed
at a real backup. AWS credentials for S3 sources go in repository/environment
secrets.

## What It Needs

1. **A PostgreSQL backup**: `pg_dump -Fc` archive (preferred — has an
   inspectable table of contents) or plain SQL dump. Local file, `file://` URL,
   or `s3://` URL (exact object or prefix).
2. **Docker** on the host/runner: restoredrill launches a throwaway Postgres
   container per drill. No persistent container is managed.
3. **`aws` CLI** if the source is S3.
4. **A config file** defining the backup source, Postgres image, checks, and
   report path.
5. **(Optional) `pg_dumpall --globals-only` file** (`backup.globals_source`) if
   you want read-path checks to run as a real application role via
   `checks.verify_as_role` — otherwise checks run as sandbox superuser and a
   missing role/grant won't surface as a failure.

## Limitations

- **Postgres only.** Roadmap: MySQL, then restic; GCS backup sources; pgBackRest
  repositories.
- **Ephemeral container model**: assumes the database fits comfortably in a
  container on the runner. Multi-terabyte estates need restore-to-dedicated-infra
  instead. restoredrill isn't that today.
- **No PITR / WAL replay**: `pg_dump`-level verification doesn't exercise
  point-in-time recovery or WAL replay. pgBackRest support (which does) is on
  the roadmap.
- **Archive integrity differs by format**: `pg_dump_custom` gets a TOC
  readability check; `pg_dump_sql` has no TOC so gets a completion-marker check
  instead. Both gated by the same `archive_integrity` flag.
- **S3 prefix + plain SQL requires a pattern**: `backup.s3_object_pattern` is
  required when combining a prefix source with `pg_dump_sql`, because plain SQL
  has no content signature to filter candidates by during selection. restoredrill
  fails at config load rather than guessing.
- **Superuser checks by default**: without `globals_source` + `verify_as_role`,
  checks run as sandbox superuser, so a missing application role/grant won't fail
  the way it would in a real recovery.
- **No built-in scheduling**: drive it with cron/CI today; "scheduled mode" is
  roadmap.
- **No trend analysis in a single report**: `restore_duration_seconds` is
  included for charting over time, but trend detection is left to whatever you
  feed reports into (log tool, dashboard, spreadsheet).
- **v0.1.0, early days**: the README warns "things may still change."

## How It Would Integrate with infrahub

restoredrill is a natural fit for an **Ansible role that deploys a scheduled
verification job** alongside existing Postgres deployments. It is not a
long-running service — it's a cron/CI one-shot — so the deployment shape is
different from most services in this repo.

### Proposed Ansible role: `restoredrill`

**Responsibilities:**

1. Install the restoredrill binary on the target host (via `go install` or a
   downloaded release binary), or run it inside a container that has Docker
   socket access.
2. Template a per-database `restoredrill.yml` config from Ansible variables,
   pointing `backup.source` at the actual backup location (local path or S3
   prefix) and defining checks appropriate to that database.
3. Install a systemd timer (or cron entry) that runs restoredrill on the
   cadence the recovery policy requires (e.g. daily).
4. Wire alerting: configure `output.prometheus_textfile` to a path the existing
   node_exporter textfile collector reads, and/or `notify.slack_webhook_url`
   from a vault secret.
5. Persist reports to a known directory (e.g. `/var/lib/restoredrill/reports/`)
   for audit retrieval.

**Two deployment shapes:**

| Shape | How | When to use |
|-------|-----|-------------|
| **Host cron + Docker** | Install restoredrill binary on the Postgres host (or a dedicated drill host); systemd timer runs `restoredrill --config ...`; Docker daemon on host launches throwaway container | Host already runs Docker; simplest; reports stay local |
| **Container job** | A container image with restoredrill + aws CLI, run on a schedule via the host's container scheduler, with Docker socket mounted (Docker-in-Docker-style) so it can spawn the Postgres sandbox | Host doesn't want a Go toolchain; prefer to keep the host clean |

The **host cron + Docker** shape is simpler and matches how restoredrill is
designed to run (it expects Docker on the host, not inside a container). The
container-job shape requires Docker socket passthrough, which is a security
consideration.

**Variable design (following infrahub `infra_` convention):**

- `infra_port_restoredrill_*` — likely not needed; restoredrill listens on no
  port. The Postgres sandbox container uses an ephemeral random port internally.
- Config values (backup source, Postgres image, check thresholds, RPO/RTO
  targets) would be service-specific vars, not infrastructure vars, since they
  describe the database being verified, not network topology.
- S3 credentials and Slack/webhook URLs go in the vault
  (`vault_restoredrill_aws_*`, `vault_restoredrill_slack_webhook_url`).

**Where it runs:**

- On the same host as the Postgres instance being verified (if backups are
  local files), or
- On a dedicated drill host with S3 access (if backups are in S3 and you don't
  want restore load on the production host), or
- In CI (GitHub Actions) using the shipped action — appropriate when backups
  are in S3 and the CI runner has AWS credentials.

**Integration with existing infrahub services:**

- **Postgres services**: each managed Postgres deployment that produces `pg_dump`
  backups gets a restoredrill config + timer. The backup tool (separate role)
  writes to a known local path or S3 prefix; restoredrill reads from there.
- **node_exporter / Prometheus**: `output.prometheus_textfile` writes to the
  textfile collector directory; alert on `restoredrill_last_run_timestamp_seconds`
  age to catch silently stopped drills. This is the primary "verified within N
  hours" signal.
- **Alerting (Slack/webhook)**: reuse existing webhook secrets from the vault.

## Comparison with Alternatives

The README names two alternatives explicitly:

### Databasus

- **Repo**: https://github.com/databasus/databasus
- **Scope**: Self-hosted backup *platform* for Postgres, MySQL, MariaDB, and
  MongoDB — it does the backups *and* the restore verification, with a full web
  UI.
- **Strength vs. restoredrill**: Multi-engine (4 databases), full web UI, one
  dashboard managing backups across several database engines. If you want a
  single pane of glass for backup management + verification across engines,
  start here.
- **Where restoredrill wins**: CI-native, fail-closed, auditor-report-first
  design. restoredrill is a check, not a platform — it composes with whatever
  you already use for backups. No dashboard to maintain; the JSON report is the
  UI. Lighter weight if you already have backups handled and just need proof.

### BackupDrill

- **Site**: https://backupdrill.com
- **Scope**: Restore verification for **Supabase specifically**, including
  Storage files (not just the Postgres database).
- **Strength vs. restoredrill**: Supabase-native, covers Storage objects too.
- **Where restoredrill wins**: Engine-agnostic Postgres (any pg_dump source —
  RDS, Supabase, local, self-hosted), CI-native, open source (MIT), self-hosted
  with no vendor dependency. BackupDrill is a hosted/SaaS product tied to
  Supabase.

### Summary

| | restoredrill | Databasus | BackupDrill |
|---|---|---|---|
| Scope | Restore verification only | Backup platform + verification | Restore verification (Supabase) |
| Engines | Postgres | Postgres, MySQL, MariaDB, MongoDB | Postgres (Supabase) + Storage |
| UI | JSON report (no dashboard) | Full web UI | (hosted product) |
| CI-native | Yes (exit code, GitHub Action) | (self-hosted platform) | (hosted product) |
| Fail-closed | Yes, by default | (platform-dependent) | (product-dependent) |
| Auditor report | First-class design goal | Dashboard-centric | (product-dependent) |
| License | MIT (open source) | (check repo) | (commercial/hosted) |
| Self-hosted | Yes | Yes | No (SaaS) |

restoredrill's niche is explicit: **a CI-native check built for an auditor's
report, not a dashboard.** If backups are already handled and you just need
proof they work on schedule, this is that.

## Recommendation for infrahub Deployment

**Adopt restoredrill as an Ansible role deploying a scheduled host-cron job for
each managed Postgres instance.**

Rationale:

1. **Fits the existing pattern.** infrahub already manages Postgres deployments
   and has a Prometheus/node_exporter stack. restoredrill is a small Go binary
   + a cron/timer + a templated config — exactly the shape of an Ansible role in
   this repo. No new long-running service, no new port, no new domain.

2. **Fills a real gap.** There is currently no automated restore verification
   for the Postgres backups this infrastructure produces. "Untested backups
   aren't backups" applies. restoredrill is the lightest-weight way to close
   that gap without standing up a backup platform.

3. **Alerting reuses existing tooling.** The Prometheus textfile metric
   (`restoredrill_last_run_timestamp_seconds`) plugs directly into the existing
   node_exporter + alertmanager stack — alert on staleness to catch a silently
   stopped drill. Slack alerts reuse existing webhook secrets. No new dashboard.

4. **Auditor-ready output.** The JSON report is designed by someone who already
   went through the SOC 2 / ISO 27001 / AWS FTR audit loop. If this
   infrastructure ever needs to prove recovery testing to an auditor, the
   reports are the evidence.

5. **Low risk, low maintenance.** Single Go binary, one YAML dependency, MIT
   license, fail-closed. The main operational caveat is that the host needs
   Docker and enough disk/RAM to restore the database into a container — which
   for the database sizes in this infrastructure is fine. For any future
   multi-TB database, revisit (restore-to-dedicated-infra would be needed).

### Suggested first step

Start with the **quickstart shape** against one non-critical Postgres instance
with a local dump file and `min_tables: 1`, run it manually via the Ansible role
to confirm the pipeline works, then layer in real checks (row counts, freshness
SQL, RPO/RTO targets) and move the source to S3 once the local path is proven.
Wire the Prometheus textfile metric last, once the drill is passing on schedule.

### Caveats to track

- **v0.1.0 / early days**: pin the version in the Ansible role
  (`version: v0.1.0`), don't track `latest`, since the schema may change.
- **Module is currently private** (the GitHub Action sets `GOPRIVATE` and uses
  `github.token` to install). Confirm the repo is accessible (public reads of
  the raw files above succeeded, so it appears public now) before relying on
  `go install` in CI; if private, build from a checkout instead.
- **No PITR**: if any Postgres instance relies on WAL archiving / PITR rather
  than `pg_dump`, restoredrill won't verify that path until pgBackRest support
  lands. Track the roadmap.
- **`verify_as_role`**: for any database where application grants matter, deploy
  with `backup.globals_source` + `checks.verify_as_role` so missing roles/grants
  surface as failures rather than being masked by superuser checks.

## References

- **Repo**: https://github.com/ahmadpiran/restoredrill
- **Quickstart config**: https://github.com/ahmadpiran/restoredrill/blob/main/examples/quickstart.yml
- **Full config**: https://github.com/ahmadpiran/restoredrill/blob/main/examples/restoredrill.yml
- **GitHub Action**: https://github.com/ahmadpiran/restoredrill/blob/main/action.yml
- **Reference workflow**: https://github.com/ahmadpiran/restoredrill/blob/main/.github/workflows/restoredrill.yml
- **go.mod**: `github.com/ahmadpiran/restoredrill`, Go 1.25, dep `gopkg.in/yaml.v3 v3.0.1`
- **Alternatives**: [Databasus](https://github.com/databasus/databasus), [BackupDrill](https://backupdrill.com)
