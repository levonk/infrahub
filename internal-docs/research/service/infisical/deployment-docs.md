# Infisical Self-Hosted Deployment Research

> **Research date**: 2026-07-14
> **Target platform**: Linux/ARM64 (aarch64) OCI cloud server (Oracle Cloud ARM)
> **Deployment method**: Docker containers managed by Ansible
> **Source repo**: https://github.com/Infisical/infisical

---

## CRITICAL ARCHITECTURE CHANGE — Read This First

> **⚠️ MAJOR FINDING**: Infisical has undergone a significant architecture change since the original
> assumptions in this research request. The platform **no longer uses MongoDB** and **no longer ships
> separate backend/frontend Docker images**. All information below reflects the *current* (2026)
> state of the project.

### Historical Timeline

| Version Range | Database | Docker Images | Tag Convention |
|---|---|---|---|
| Before `v0.46.11` | **MongoDB** | `infisical/backend` + `infisical/frontend` (separate) | No suffix |
| `v0.46.11` – `v0.147.0` | **PostgreSQL** | `infisical/infisical` (combined) | `-postgres` suffix |
| After `v0.147.0` (current) | **PostgreSQL** | `infisical/infisical` (combined) | No suffix (e.g., `v0.162.6`) |

The old `infisical/backend` and `infisical/frontend` images on Docker Hub are **2+ years old** and
**deprecated**. They should NOT be used for new deployments.

The environment variables `MONGODB_URL`, `JWT_SIGNUP_SECRET`, `JWT_REFRESH_SECRET`, and
`JWT_AUTH_SECRET` mentioned in the original research request are **no longer used**. The current
platform uses `DB_CONNECTION_URI` (PostgreSQL) and a single `AUTH_SECRET` for JWT signing.

---

## 1. Architecture

### Current Architecture (2026)

A full self-hosted Infisical deployment consists of **three containers**:

| Component | Role | Docker Image |
|---|---|---|
| **Infisical App** | Combined frontend (Next.js) + backend (Node.js/Fastify) + internal nginx | `infisical/infisical:<version>` |
| **PostgreSQL** | Primary relational database — stores encrypted secrets, users, projects, audit logs | `postgres:14-alpine` |
| **Redis** | Caching and background job queues (BullMQ) | `redis` (or `redis:7-alpine`) |

### Internal Architecture of the Combined Image

The `infisical/infisical` image is a multi-stage build that bundles:

1. **Frontend** — Next.js app served on internal port `3000`
2. **Backend** — Fastify-based Node.js API server on internal port `4000`
3. **Nginx** — Internal reverse proxy (listening on port `8080`) that routes:
   - `/api/*` and `/secret-scanning/webhooks` → `backend:4000`
   - `/scep`, `/.well-known/est` → `backend:4000`
   - `/api/v1/pam/accounts/*/web-access` → `backend:4000` (WebSocket)
   - `/` (everything else) → `frontend:3000`

The container's entrypoint (`standalone-entrypoint.sh`) runs:
```sh
update-ca-certificates
exec node --enable-source-maps dist/main.mjs
```

The internal nginx config (`nginx/default.conf`) handles the routing between frontend and backend
within the single container. **Only port 8080 needs to be exposed externally.**

### Optional Components

| Component | Purpose | When Needed |
|---|---|---|
| **ClickHouse** | High-performance audit log storage | High-volume deployments (`clickhouse/clickhouse-server`) |
| **SMTP server** | Email notifications (password reset, invites) | Production (external, not a container) |
| **db-migration** | One-shot migration runner | After upgrades (uses same `infisical/infisical` image) |

---

## 2. Container Requirements

### 2.1 Infisical App Container

| Property | Value |
|---|---|
| **Image** | `infisical/infisical:<version>` (e.g., `infisical/infisical:v0.162.6`) |
| **Registry** | Docker Hub — https://hub.docker.com/r/infisical/infisical |
| **Internal port** | `8080` (nginx, routes to frontend:3000 and backend:4000) |
| **Host port** | Typically `80:8080` or `443:8080` (behind reverse proxy) |
| **Volumes** | None required (stateless — all state in Postgres/Redis) |
| **Healthcheck** | `GET /api/status` — returns HTTP 200 when healthy |
| **Restart policy** | `unless-stopped` |

#### Required Environment Variables

| Variable | Type | Required | Description |
|---|---|---|---|
| `ENCRYPTION_KEY` | string | **Yes** | Random 16-byte hex string. Generate with `openssl rand -hex 16`. **FIPS**: use `openssl rand -base64 32` instead. |
| `AUTH_SECRET` | string | **Yes** | Random 32-byte base64 string. Generate with `openssl rand -base64 32`. Signs all JWT tokens. |
| `DB_CONNECTION_URI` | string | **Yes** | PostgreSQL connection string. Format: `postgres://user:password@host:5432/dbname` |
| `REDIS_URL` | string | **Yes** | Redis connection string. Format: `redis://host:6379` |
| `SITE_URL` | string | **Yes** | Absolute URL including protocol (e.g., `https://infisical.example.com`) |

#### Important Optional Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | Internal listening port |
| `HOST` | `localhost` | Bind address. Set to `0.0.0.0` for external access. |
| `NODE_ENV` | — | Set to `production` for deployments |
| `TELEMETRY_ENABLED` | `true` | Set to `false` to disable telemetry |
| `CORS_ALLOWED_ORIGINS` | (defaults to `SITE_URL`) | JSON array of allowed origins, e.g., `["https://example.com"]` |
| `TRUSTED_PROXY_CIDRS` | (unset = trust all) | Comma-separated CIDR ranges for reverse proxy IP trust. **Set this behind Traefik.** |
| `DB_ROOT_CERT` | — | Base64-encoded CA certificate for SSL Postgres connections |
| `DB_READ_REPLICAS` | — | JSON array of read replica connection strings |
| `SMTP_HOST` | — | SMTP server hostname for email |
| `SMTP_PORT` | — | SMTP server port |
| `SMTP_FROM_ADDRESS` | — | From email address |
| `SMTP_USERNAME` | — | SMTP auth username |
| `SMTP_PASSWORD` | — | SMTP auth password |

#### Redis SSL/TLS Variables (Optional)

| Variable | Description |
|---|---|
| `NODE_EXTRA_CA_CERTS` | Path to CA cert file for self-signed Redis/Postgres TLS |
| `REDIS_SENTINEL_ENABLE_TLS` | Enable TLS for Redis Sentinel connections |
| `REDIS_CLUSTER_ENABLE_TLS` | Enable TLS for Redis Cluster connections |

#### SSO Variables (Optional — all blank by default)

| Variable | Description |
|---|---|
| `CLIENT_ID_GOOGLE_LOGIN` / `CLIENT_SECRET_GOOGLE_LOGIN` | Google OAuth SSO |
| `CLIENT_ID_GITHUB_LOGIN` / `CLIENT_SECRET_GITHUB_LOGIN` | GitHub OAuth SSO |
| `CLIENT_ID_GITLAB_LOGIN` / `CLIENT_SECRET_GITLAB_LOGIN` | GitLab OAuth SSO |
| `CAPTCHA_SECRET` / `NEXT_PUBLIC_CAPTCHA_SITE_KEY` | CAPTCHA for signup |

#### Healthcheck Configuration (for docker-compose)

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/api/status"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

> **Note**: The healthcheck requires `curl` to be available inside the container. The official
> `infisical/infisical` image is based on a Debian/Node image that includes `curl`. If using a
> minimal image variant, verify `curl` availability or use `wget` instead.

### 2.2 PostgreSQL Container

| Property | Value |
|---|---|
| **Image** | `postgres:14-alpine` (official docker-compose uses this) |
| **Port** | `5432` (internal only — no need to expose externally) |
| **Volume** | `pg_data:/var/lib/postgresql/data` — **CRITICAL: contains all encrypted secrets** |
| **Healthcheck** | `pg_isready --username=${POSTGRES_USER} && psql --username=${POSTGRES_USER} --list` |

#### PostgreSQL Environment Variables

| Variable | Description |
|---|---|
| `POSTGRES_USER` | Database username (e.g., `infisical`) |
| `POSTGRES_PASSWORD` | Database password — **generate a strong password** |
| `POSTGRES_DB` | Database name (e.g., `infisical`) |

> **Note**: The database user must have ALL privileges on the Infisical database, including the
> ability to create new schemas, tables, indexes, etc.

#### Healthcheck Configuration

```yaml
healthcheck:
  test: "pg_isready --username=${POSTGRES_USER} && psql --username=${POSTGRES_USER} --list"
  interval: 5s
  timeout: 10s
  retries: 10
```

### 2.3 Redis Container

| Property | Value |
|---|---|
| **Image** | `redis` (official) or `redis:7-alpine` (recommended for production) |
| **Port** | `6379` (internal only — no need to expose externally) |
| **Volume** | `redis_data:/data` (cache data — can be regenerated if lost) |
| **Healthcheck** | Not included in official docker-compose; can add `redis-cli ping` |

#### Redis Environment Variables

| Variable | Description |
|---|---|
| `ALLOW_EMPTY_PASSWORD` | Set to `yes` for development (official compose default). **Set a password for production.** |

---

## 3. Multi-Arch Support (linux/arm64)

### ✅ CONFIRMED: Official images support linux/arm64

The `infisical/infisical` image on Docker Hub **supports both `linux/amd64` and `linux/arm64`**.

Verified from Docker Hub tags page (https://hub.docker.com/r/infisical/infisical/tags):

| Tag | linux/amd64 | linux/arm64 | Compressed (amd64) | Compressed (arm64) |
|---|---|---|---|---|
| `v0.162.6` (latest) | ✅ | ✅ | 722.99 MB | 703.81 MB |
| `v0.162.5` | ✅ | ✅ | 725.09 MB | 705.91 MB |
| `v0.162.4` | ✅ | ✅ | 725.12 MB | 705.93 MB |
| `v0.162.3` | ✅ | ✅ | 722.3 MB | — |
| `latest` | ✅ | ✅ | 722.99 MB | 703.81 MB |

> **Image size note**: The compressed image is ~700 MB; the uncompressed image will be significantly
> larger (likely 1.5–2 GB). Ensure adequate disk space on the ARM64 server.

### Dependency Images ARM64 Support

| Image | ARM64 Support |
|---|---|
| `postgres:14-alpine` | ✅ (officially multi-arch) |
| `redis` / `redis:7-alpine` | ✅ (officially multi-arch) |

**Conclusion**: The entire stack is compatible with Oracle Cloud ARM (aarch64) servers.

---

## 4. Database Requirement (PostgreSQL — NOT MongoDB)

> **⚠️ MongoDB is NOT used.** Infisical migrated from MongoDB to PostgreSQL at version `v0.46.11`.
> Any documentation or guides referencing MongoDB are outdated.

### PostgreSQL Version

- **Official docker-compose**: `postgres:14-alpine`
- **Minimum requirement**: PostgreSQL 14 (as used in official compose)
- **Recommended**: PostgreSQL 14 or 15 for production

### Replica Set / Clustering

- **No replica set required** (this was a MongoDB concept; PostgreSQL uses different replication)
- PostgreSQL read replicas are **optional** — configured via `DB_READ_REPLICAS` env var
- For a single-server Docker deployment, a standalone PostgreSQL instance is sufficient

### Connection String Format

```
postgres://USER:PASSWORD@HOST:5432/DBNAME
```

Example (from official `.env.example`):
```
DB_CONNECTION_URI=postgres://infisical:infisical@db:5432/infisical
```

With SSL:
```
DB_CONNECTION_URI=postgres://user:pass@host:5432/dbname?sslmode=verify-ca
DB_ROOT_CERT=<base64-encoded-ca-certificate>
```

### Database User Privileges

The database user must be granted **all privileges** on the Infisical database:
- Create new schemas
- Create, update, delete, modify tables and indexes
- Run migrations (the app auto-runs migrations on startup)

---

## 5. Redis Requirement

### Redis Version

- **Official docker-compose**: `redis` (latest, unspecified version)
- **Recommended**: `redis:7-alpine` for production (pinned version, smaller image)

### Mode

- **Standalone** Redis is sufficient for single-server deployments
- Infisical also supports **Redis Sentinel** and **Redis Cluster** for HA
- **Active-passive** setup is recommended; active-active has NOT been tested

### Connection String Formats

| Mode | Format |
|---|---|
| Without SSL | `redis://localhost:6379` |
| With SSL | `rediss://localhost:6379` (note double 's') |
| With auth | `redis://:password@localhost:6379` |
| With SSL + auth | `rediss://:password@localhost:6379` |
| Sentinel | `REDIS_SENTINEL_HOSTS=host1:26379,host2:26379` + `REDIS_SENTINEL_NAME=mymaster` |
| Cluster | `REDIS_CLUSTER_HOSTS=host1:6379,host2:6379,host3:6379` |

### Production Recommendation

For a single Oracle Cloud ARM server:
- Use `redis:7-alpine` standalone
- Set a Redis password (do NOT use `ALLOW_EMPTY_PASSWORD=yes` in production)
- Persist data with a named volume (though Redis data is cache/queue and can be regenerated)

---

## 6. Initial Setup / Bootstrap

### Method 1: Web UI (Default)

The **first user to sign up** via the web interface becomes the instance administrator (super admin).

1. Deploy Infisical (docker compose up)
2. Navigate to `http://<server-ip>` (or your domain)
3. Complete the signup form with admin email and password
4. Download the **Emergency Kit PDF** (the only way to regain access if locked out)
5. After setup, **disable user signups** in Server Settings to prevent unauthorized access

> **Important**: Complete the admin signup BEFORE exposing Infisical to other users.

### Method 2: CLI Bootstrap (Automated / Headless)

The Infisical CLI provides a `bootstrap` command for automated, UI-less setup — ideal for Ansible:

```bash
infisical bootstrap \
  --domain="https://infisical.example.com" \
  --email="admin@example.com" \
  --password="your-secure-password" \
  --organization="My Organization"
```

Environment variable equivalents:
- `INFISICAL_API_URL` → `--domain`
- `INFISICAL_ADMIN_EMAIL` → `--email`
- `INFISICAL_ADMIN_PASSWORD` → `--password`
- `INFISICAL_ADMIN_ORGANIZATION` → `--organization`

#### Bootstrap Response

The command returns JSON with the admin user, organization, and a **machine identity token**:

```json
{
  "identity": {
    "credentials": {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    },
    "id": "db224792-ed18-4277-9dae-57e752315854",
    "name": "Instance Admin Identity"
  },
  "message": "Successfully bootstrapped instance",
  "organization": {
    "id": "b56bece0-42f5-4262-b25e-be7bf5f84957",
    "name": "My Organization",
    "slug": "my-organization-xxxxx"
  },
  "user": {
    "email": "admin@example.com",
    "firstName": "Admin",
    "id": "a418f355-c8da-453c-bbc8-6c07208eeb3c",
    "lastName": "User",
    "superAdmin": true,
    "username": "admin@example.com"
  }
}
```

Extract just the token for automation:
```bash
TOKEN=$(infisical bootstrap \
  --domain="https://infisical.example.com" \
  --email="admin@example.com" \
  --password="$ADMIN_PASSWORD" \
  --organization="My Org" | jq -r ".identity.credentials.token")
```

#### Idempotent Bootstrap

Use `--ignore-if-bootstrapped` for idempotent Ansible playbooks:
```bash
infisical bootstrap --domain=... --email=... --password=... --organization=... --ignore-if-bootstrapped
```

### Method 3: API Bootstrap

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"your-secure-password","organization":"your-org-name"}' \
  https://infisical.example.com/api/v1/admin/bootstrap
```

### Bootstrap Flow for Ansible

1. Deploy containers with Docker Compose
2. Wait for healthcheck (`/api/status` returns 200)
3. Run `infisical bootstrap` via CLI or API call
4. Store the returned machine identity token securely (Ansible vault)
5. Use the token for further API-driven configuration

> **Note**: Bootstrap can only be performed **once** on a fresh instance.

---

## 7. Networking

### Port Exposure

| Port | Protocol | Exposed | Purpose |
|---|---|---|---|
| `8080` (container) / `80` (host) | HTTP | **Yes** — single entry point | Infisical web UI + API |
| `5432` | TCP | **No** — internal only | PostgreSQL |
| `6379` | TCP | **No** — internal only | Redis |

### Routing Architecture

The combined `infisical/infisical` container uses an **internal nginx** to route traffic:

```
External request → :8080 (nginx)
    ├── /api/*              → backend (Node.js/Fastify) on :4000
    ├── /secret-scanning/*  → backend on :4000
    ├── /scep               → backend on :4000
    ├── /.well-known/est    → backend on :4000
    └── / (everything else) → frontend (Next.js) on :3000
```

**There is a single external entry point (port 8080).** The frontend and backend are NOT separate
services — they are internal processes within the same container, routed by the internal nginx.

### Behind a Reverse Proxy (Traefik/Nginx)

When placing Infisical behind an external reverse proxy:
- Expose only port 8080 from the Infisical container
- The external proxy handles TLS termination
- Forward all traffic to `infisical:8080`
- Set `TRUSTED_PROXY_CIDRS` to the proxy's CIDR range for correct IP handling
- Set `SITE_URL` to the external URL (e.g., `https://infisical.example.com`)

---

## 8. Official docker-compose.yml

### Source

The official production docker-compose file is at:
`https://raw.githubusercontent.com/Infisical/infisical/main/docker-compose.prod.yml`

### Official docker-compose.prod.yml (verbatim)

```yaml
version: "3"

services:
  backend:
    container_name: infisical-backend
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    image: infisical/infisical:latest # PIN THIS TO A SPECIFIC TAG
    pull_policy: always
    env_file: .env
    ports:
      - 80:8080
    environment:
      - NODE_ENV=production
    networks:
      - infisical

  redis:
    image: redis
    container_name: infisical-dev-redis
    env_file: .env
    restart: always
    environment:
      - ALLOW_EMPTY_PASSWORD=yes
    networks:
      - infisical
    volumes:
      - redis_data:/data

  db:
    container_name: infisical-db
    image: postgres:14-alpine
    restart: always
    env_file: .env
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - infisical
    healthcheck:
      test: "pg_isready --username=${POSTGRES_USER} && psql --username=${POSTGRES_USER} --list"
      interval: 5s
      timeout: 10s
      retries: 10

volumes:
  pg_data:
    driver: local
  redis_data:
    driver: local

networks:
  infisical:
```

### Official .env.example (key variables)

```bash
# === REQUIRED KEYS ===
# Generate with: openssl rand -hex 16
ENCRYPTION_KEY=f13dbc92aaaf86fa7cb0ed8ac3265f47

# Generate with: openssl rand -base64 32
AUTH_SECRET=5lrMXKKWCVocS/uerPsl7V+TX/aaUaI7iDkgl3tSmLE=

# === POSTGRES ===
POSTGRES_PASSWORD=infisical
POSTGRES_USER=infisical
POSTGRES_DB=infisical
DB_CONNECTION_URI=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}

# === REDIS ===
REDIS_URL=redis://redis:6379

# === SITE ===
SITE_URL=http://localhost:8080

# === SMTP (optional) ===
SMTP_HOST=
SMTP_PORT=
SMTP_FROM_ADDRESS=
SMTP_FROM_NAME=
SMTP_USERNAME=
SMTP_PASSWORD=

# === TELEMETRY ===
# (not in .env.example but supported — set TELEMETRY_ENABLED=false to disable)

# === SSO (optional) ===
CLIENT_ID_GOOGLE_LOGIN=
CLIENT_SECRET_GOOGLE_LOGIN=
CLIENT_ID_GITHUB_LOGIN=
CLIENT_SECRET_GITHUB_LOGIN=
CLIENT_ID_GITLAB_LOGIN=
CLIENT_SECRET_GITLAB_LOGIN=
CAPTCHA_SECRET=
NEXT_PUBLIC_CAPTCHA_SITE_KEY=

# === Sentry (optional) ===
SENTRY_DSN=

# === OpenTelemetry (optional) ===
OTEL_TELEMETRY_COLLECTION_ENABLED=false
OTEL_EXPORT_TYPE=prometheus
OTEL_EXPORT_OTLP_ENDPOINT=
```

### Structure Summary

The official compose file defines:
- **3 services**: `backend` (Infisical app), `db` (PostgreSQL), `redis` (Redis)
- **2 named volumes**: `pg_data` (critical data), `redis_data` (cache)
- **1 network**: `infisical` (internal bridge network)
- **Dependencies**: `backend` waits for `db` healthcheck + `redis` start
- **No healthcheck on backend** (can be added — see Section 2.1)
- **No healthcheck on redis** (can be added)

### Enhanced docker-compose (from community/Ansible guide)

A more production-ready version from the linux-server-admin.com Ansible guide adds:

```yaml
services:
  backend:
    image: infisical/infisical:{{ infisical_version }}
    container_name: infisical-backend
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
      db-migration:
        condition: service_completed_successfully
    env_file: .env
    environment:
      - NODE_ENV=production
    ports:
      - "{{ infisical_host_port }}:{{ infisical_container_port }}"
    networks:
      - infisical
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{{ infisical_container_port }}/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    read_only: true
    tmpfs:
      - /tmp:rw,exec,size=1G
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true

  db-migration:
    container_name: infisical-db-migration
    depends_on:
      db:
        condition: service_healthy
    image: infisical/infisical:{{ infisical_version }}
    env_file: .env
    command: npm run migration:latest
    pull_policy: always
    networks:
      - infisical

  redis:
    image: redis:7-alpine
    container_name: infisical-redis
    restart: unless-stopped
    env_file: .env
    environment:
      - ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - redis_data:/data
    networks:
      - infisical

  db:
    container_name: infisical-db
    image: postgres:14-alpine
    restart: unless-stopped
    env_file: .env
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - infisical
    healthcheck:
      test: "pg_isready --username=${POSTGRES_USER} && psql --username=${POSTGRES_USER} --list"
      interval: 5s
      timeout: 10s
      retries: 10
```

> **Note on db-migration**: The official compose auto-runs migrations on backend startup. The
> community version separates migrations into a one-shot init container for better control. Both
> approaches work.

---

## 9. Security Considerations

### Secrets/Keys to Generate for Production

| Secret | Generation Command | Purpose | Criticality |
|---|---|---|---|
| `ENCRYPTION_KEY` | `openssl rand -hex 16` | Encrypts/decrypts all stored secrets. **If lost, all data is unrecoverable.** | 🔴 CRITICAL |
| `AUTH_SECRET` | `openssl rand -base64 32` | Signs all JWT authentication tokens | 🔴 CRITICAL |
| `POSTGRES_PASSWORD` | `openssl rand -base64 24` | Database access password | 🔴 CRITICAL |
| Redis password | `openssl rand -base64 24` | Redis access (do NOT use empty password in prod) | 🟡 HIGH |
| Admin password | (strong password) | Initial admin user password for bootstrap | 🔴 CRITICAL |

### Key Management Best Practices

1. **ENCRYPTION_KEY**: 
   - Store in Ansible Vault (or external secret manager)
   - **NEVER lose this key** — all encrypted secrets become unrecoverable without it
   - Back up to offline storage (e.g., printed Emergency Kit)
   - For FIPS deployments: use `openssl rand -base64 32` instead

2. **AUTH_SECRET**:
   - Store in Ansible Vault
   - Rotating this invalidates all existing JWT sessions (users must re-login)

3. **POSTGRES_PASSWORD**:
   - Store in Ansible Vault
   - Use a strong random password (not a human-readable one)

4. **PostgreSQL data volume (`pg_data`)**:
   - Contains all encrypted secrets, users, projects, configuration
   - **NEVER delete this volume** unless intentionally destroying all data
   - Back up regularly: `docker exec infisical-db pg_dump -U infisical infisical > backup.sql`

### Network Security

- Do NOT expose PostgreSQL (5432) or Redis (6379) ports externally
- Use Docker internal networking only
- Place behind a reverse proxy (Traefik) with TLS
- Set `TRUSTED_PROXY_CIDRS` to prevent IP spoofing via proxy headers
- Set `TELEMETRY_ENABLED=false` for air-gapped/privacy-sensitive deployments
- Disable user signups after initial admin creation

### Container Hardening (from community Ansible guide)

```yaml
read_only: true
tmpfs:
  - /tmp:rw,exec,size=1G
cap_drop:
  - ALL
security_opt:
  - no-new-privileges:true
```

> **Uncertainty**: The `read_only: true` flag may cause issues if the Infisical app needs to write
> to filesystem paths other than `/tmp`. Test carefully before applying in production.

---

## 10. Traefik Integration Notes

### Architecture Context

The `infisical/infisical` container is a **single image** with an internal nginx that handles
routing between the Next.js frontend (port 3000) and the Node.js backend (port 4000). The container
exposes a single port (8080) that Traefik routes to.

### Traefik Configuration

**Single router is sufficient** — Traefik only needs to route to one container port (8080). The
internal nginx handles frontend/backend splitting.

#### Traefik labels for the Infisical container:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.infisical.rule=Host(`infisical.example.com`)"
  - "traefik.http.routers.infisical.entrypoints=websecure"
  - "traefik.http.routers.infisical.tls=true"
  - "traefik.http.routers.infisical.tls.certresolver=letsencrypt"
  - "traefik.http.services.infisical.loadbalancer.server.port=8080"
  # WebSocket support (for PAM web access)
  - "traefik.http.routers.infisical.middlewares=infisical-headers"
  - "traefik.http.middlewares.infisical-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.infisical-headers.headers.forceSTSHeader=true"
  - "traefik.http.middlewares.infisical-headers.headers.customFrameOptionsValue=SAMEORIGIN"
```

### Key Points for Traefik Integration

1. **Single entry point**: Traefik routes everything to `infisical:8080`. No need for separate
   frontend/backend routers.

2. **WebSocket support**: The `/api/v1/pam/accounts/*/web-access` endpoint uses WebSockets.
   Traefik handles WebSocket upgrades automatically — no special configuration needed beyond
   standard HTTP routing.

3. **TLS termination**: Traefik handles TLS. The Infisical internal nginx listens on plain HTTP
   (port 8080). Do NOT configure TLS inside the Infisical container when using Traefik.

4. **SITE_URL**: Must be set to the Traefik-facing URL: `SITE_URL=https://infisical.example.com`

5. **TRUSTED_PROXY_CIDRS**: Set to the Docker network CIDr or Traefik's IP range to ensure
   Infisical trusts the `X-Forwarded-For` header from Traefik:
   ```
   TRUSTED_PROXY_CIDRS=172.16.0.0/12
   ```
   (Adjust to match your Docker network subnet)

6. **CORS**: If the frontend and API are served from the same domain (which they are, via the
   combined image), CORS is handled internally. `CORS_ALLOWED_ORIGINS` defaults to `SITE_URL`.

7. **Large body support**: The `/api/v3/migrate` endpoint accepts up to 25MB, and KMS
   encrypt/decrypt endpoints accept up to 2MB. Traefik's default body size limit may need
   adjustment:
   ```yaml
   - "traefik.http.middlewares.infisical-body.buffering.maxRequestBodyBytes=26214400"
   ```

### No Separate Routers Needed

Because the combined image's internal nginx already handles path-based routing (`/api/*` → backend,
`/` → frontend), Traefik does **not** need separate routers for the API and dashboard. A single
`Host(`infisical.example.com`)` rule covers everything.

---

## System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 50 GB+ (SSD recommended) |

> These requirements include Infisical, PostgreSQL, and Redis containers. For larger deployments
> with many secrets or users, increase resources accordingly.

---

## Ansible Deployment Notes

### Key Considerations for Ansible

1. **Image pinning**: Pin to a specific version tag (e.g., `v0.162.6`), not `latest`
2. **Migration handling**: The official image auto-runs migrations on startup. For more control,
   use a separate `db-migration` init container with `command: npm run migration:latest`
3. **Health verification**: Use `uri` module to check `http://localhost:8080/api/status`:
   ```yaml
   - name: Verify Infisical API health
     ansible.builtin.uri:
       url: "http://127.0.0.1:{{ infisical_container_port }}/api/status"
       method: GET
       status_code: 200
     register: api_health
     until: api_health.status == 200
     retries: 10
     delay: 10
   ```
4. **Bootstrap automation**: Use the `infisical bootstrap` CLI command or API call after health
   check passes
5. **Secret generation**: Generate `ENCRYPTION_KEY` and `AUTH_SECRET` with Ansible's `openssl`
   commands and store in Ansible Vault

### Suggested Ansible Task Flow

1. Generate secrets (if not already in vault): `ENCRYPTION_KEY`, `AUTH_SECRET`, `POSTGRES_PASSWORD`
2. Create `.env` file from vault variables
3. Deploy docker-compose (db + redis + infisical)
4. Wait for PostgreSQL healthcheck
5. Wait for Infisical `/api/status` healthcheck
6. Run `infisical bootstrap` (CLI or API) with `--ignore-if-bootstrapped`
7. Store returned machine identity token in vault
8. Configure server settings via API (disable signups, etc.)

---

## Uncertainties and Caveats

1. **`read_only: true` container hardening**: May cause issues if Infisical writes to filesystem
   paths other than `/tmp`. The community Ansible guide uses it with a tmpfs mount for `/tmp`, but
   this has not been verified against all Infisical features.

2. **Redis password in official compose**: The official `docker-compose.prod.yml` uses
   `ALLOW_EMPTY_PASSWORD=yes` which is insecure. For production, a Redis password should be set
   and the `REDIS_URL` updated to include it. The exact mechanism for setting a Redis password in
   the official Redis image is via `REDIS_PASSWORD` env var or a custom `redis.conf`.

3. **Migration strategy**: The official compose auto-runs migrations on backend startup. Whether
   this is safe for zero-downtime upgrades in production is unclear. The community guide separates
   migrations into an init container, which provides better control.

4. **Image size**: The `infisical/infisical` image is ~700 MB compressed (both architectures).
   Uncompressed, it will be significantly larger. Ensure the ARM64 server has adequate disk space.

5. **ClickHouse for audit logs**: The official docs mention ClickHouse as an optional audit log
   backend, but the official `docker-compose.prod.yml` does not include it. For high-volume audit
   logging, this would need to be added separately.

6. **FIPS image**: A separate `infisical/infisical-fips` image exists on Docker Hub for FIPS 140-3
   compliant deployments. This has different `ENCRYPTION_KEY` requirements (256-bit base64 instead
   of 128-bit hex). Not needed for standard deployments.

7. **Internal port mapping**: The internal nginx config references `backend:4000` and
   `frontend:3000` as if they were separate services. In the combined standalone image, these are
   internal processes within the same container. The nginx config works because the processes bind
   to `localhost:4000` and `localhost:3000` within the container's network namespace.

---

## Source References

- **GitHub repo**: https://github.com/Infisical/infisical
- **Official docker-compose.prod.yml**: https://raw.githubusercontent.com/Infisical/infisical/main/docker-compose.prod.yml
- **Official .env.example**: https://raw.githubusercontent.com/Infisical/infisical/main/.env.example
- **Self-hosting overview**: https://infisical.com/docs/self-hosting/overview
- **Docker Compose guide**: https://infisical.com/docs/self-hosting/deployment-options/docker-compose
- **Standalone Docker guide**: https://infisical.com/docs/self-hosting/deployment-options/standalone-infisical
- **Environment variables reference**: https://infisical.com/docs/self-hosting/configuration/envars
- **Automated bootstrapping**: https://infisical.com/docs/self-hosting/guides/automated-bootstrapping
- **CLI bootstrap command**: https://infisical.com/docs/cli/commands/bootstrap
- **Docker Hub images**: https://hub.docker.com/u/infisical
- **Docker Hub tags (infisical/infisical)**: https://hub.docker.com/r/infisical/infisical/tags
- **Internal nginx config**: https://raw.githubusercontent.com/Infisical/infisical/main/nginx/default.conf
- **Homelab blog post**: https://infisical.com/blog/self-hosting-infisical-homelab
- **Ansible deployment guide (community)**: https://wiki.linux-server-admin.com/web-apps/vault-secret-management/infisical/setup/ansible
- **Mongo-to-Postgres migration docs**: https://infisical.com/docs/self-hosting/guides/mongo-to-postgres
- **DeepWiki architecture analysis**: https://deepwiki.com/Infisical/infisical/3.2-self-hosting-options
