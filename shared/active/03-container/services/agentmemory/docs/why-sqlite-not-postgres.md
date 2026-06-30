# Why agentmemory Uses SQLite (Not Postgres)

## Decision

agentmemory uses iii-engine's file-based SQLite KV state (`store_method: file_based`, `/data/state_store.db`) as its persistence layer. We do **not** switch to Postgres.

## Rationale

### 1. iii-engine doesn't support Postgres as a state adapter

The iii-config only exposes `store_method: file_based` for the `iii-state` worker. The iii-sdk is a WebSocket client to the iii-engine daemon, which handles state internally via its KV adapter. There is no `postgres` or `database_url` option in the iii-engine config schema. Switching to Postgres would require writing a new state adapter in iii-engine itself — a pinned upstream binary (`iiidev/iii:0.11.2`) we don't control — not just changing agentmemory's config.

### 2. agentmemory's architecture is deliberately Postgres-free

The README explicitly positions this as a feature:

> You didn't install Postgres, Redis, Express, pm2, or Prometheus, because iii replaces them.
>
> | SQLite / Postgres + pgvector | iii KV State + in-memory vector index |

The state layer is a KV store (`mem:sessions`, `mem:obs:*`, `mem:memories`, etc. — see `src/state/schema.ts`), not relational tables. Postgres would be a category mismatch: using a relational database to emulate a KV store is the worst of both worlds.

### 3. The vector index is in-memory, not in the DB

agentmemory does hybrid search (BM25 + vector). The BM25 index lives in KV state; the vector index is in-memory in the agentmemory process. Even if you swapped the KV backing store to Postgres, the vector embeddings would still be in RAM. You'd gain nothing for the most performance-sensitive part.

### 4. Adding a failure dependency for no benefit

Current setup: one container, one volume, one process. If the container restarts, state persists in `/data/state_store.db`. Backups are `cp /data/state_store.db`.

With Postgres: agentmemory is down whenever Postgres is down. You'd need Postgres HA, connection pooling, WAL archiving — for a single-user agent memory store that handles maybe a few hundred writes per coding session. SQLite's WAL mode handles this concurrency trivially.

### 5. Postgres is already used where it belongs

Authelia uses Postgres (user sessions, OIDC, WebAuthn — relational data with joins). That's the right tool for that job. agentmemory's KV-with-vectors is not.

## When Postgres *would* make sense

- **Multi-tenant shared service**: many developers with concurrent writes from 50+ agents simultaneously
- **Cross-host replication**: agentmemory running on multiple cloud servers sharing one memory store

Neither applies to the current setup — single cloud server, single user, Tailscale-only access.

## What we do instead for durability

- **Volume backups**: snapshot the `localnet-agentmemory-data-volume` to the backup dir (`/opt/localnet/backup/agentmemory/`) on a schedule
- **Export/import**: agentmemory has built-in export/import (`src/functions/export-import.ts`) — dump the full memory state to JSON for off-host backups

Both work with the current SQLite setup and require zero architectural changes.
