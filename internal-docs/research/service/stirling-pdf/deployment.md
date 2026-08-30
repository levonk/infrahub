# Stirling-PDF — Docker Deployment

Target environment: Windows Docker Desktop host, X86 (amd64) architecture, `nl.levonk.com` network.

## Official container image

Stirling-PDF is published to **three registries**. All are official and maintained by the project:

| Registry | Image reference | Notes |
|----------|----------------|-------|
| **Stirling's own proxy** | `docker.stirlingpdf.com/stirlingtools/stirling-pdf` | Recommended by the project; used in all official docs and quick-start commands |
| **Docker Hub** | `stirlingtools/stirling-pdf` | Also official; same tags |
| **GHCR** | `ghcr.io/stirling-tools/s-pdf` | GitHub Container Registry. Note: the package name is `s-pdf`, not `stirling-pdf` |

> **Important**: The project has asked users to migrate to the `docker.stirlingpdf.com` proxy URL to
> avoid issues during package migrations. The old `frooodle/s-pdf` and `frooodle/stirling-pdf`
> images are deprecated.

**Sources**:
- https://hub.docker.com/r/stirlingtools/stirling-pdf
- https://github.com/Stirling-Tools/Stirling-PDF/pkgs/container/s-pdf
- https://docs.stirlingpdf.com/Installation/Docker%20Install/

### Tag strategy

Three variant lines, each with rolling and SemVer tags:

| Variant | Rolling tag | Description | Compressed size (amd64) |
|---------|------------|-------------|------------------------|
| **Standard** | `latest` | All PDF features, balanced size. **Recommended for most users.** | ~1,018 MB |
| **Fat** | `latest-fat` | Everything + extra fonts and tools for highest quality conversions and full format support | ~1.9 GB |
| **Ultra-Lite** | `latest-ultra-lite` | Core features only, minimal size for resource-constrained environments. **No authentication/login built in.** | ~320 MB |

SemVer tags are also published (e.g. `2.14.3`, `2.14.3-fat`, `2.14.3-ultra-lite`, plus minor/major
rollups `2.14`, `2`). For production, **pin to a specific SemVer tag** rather than `latest`.

**For the target deployment** (Windows Docker Desktop, X86, with login/SSO): use
`docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest` (or a pinned SemVer like
`docker.stirlingpdf.com/stirlingtools/stirling-pdf:2.14.3`). The standard image includes
authentication and additional features enabled by default.

## Architecture support

The official images are multi-arch and support:

- **`linux/amd64`** — ✅ **Fully supported** (this is the target for Windows Docker Desktop X86)
- **`linux/arm64`** — ✅ Fully supported

Windows Docker Desktop runs Linux containers via WSL2, so the `linux/amd64` image runs natively on
an X86 host. No special configuration needed — Docker will automatically pull the `amd64` variant.

**Source**: Docker Hub tag listing confirms both `linux/amd64` and `linux/arm64` for all variants.
https://hub.docker.com/r/stirlingtools/stirling-pdf/tags

## Default port

- **Internal HTTP port**: `8080`
- The container exposes `8080/tcp` and the Spring Boot application listens on `8080` by default.
- Map with `-p 8080:8080` (or use a reverse proxy and only expose internally).

```bash
docker run -d \
  --name stirling-pdf \
  -p 8080:8080 \
  -v ./stirling-data:/configs \
  docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest
```

## Required volumes / config directories / data paths

The following paths inside the container should be mounted as volumes for persistence:

| Container path | Purpose | Required? |
|---------------|---------|-----------|
| `/configs` | **Settings & database** — contains `settings.yml`, `custom_settings.yml`, and the H2 database file (`stirling-pdf-DB-<version>.mv.db`). **Most important volume.** | Yes (strongly recommended) |
| `/usr/share/tessdata` | OCR language files (Tesseract) | Optional (only if using OCR) |
| `/logs` | Application logs | Optional (recommended) |
| `/pipeline` | Automation/pipeline configurations and watched/finished folders | Optional (only if using pipelines/folder scanning) |
| `/customFiles` | Custom branding files, static asset overrides, signature files | Optional |
| `/tmp/stirling-pdf` | Temporary processing files | Optional (can use a tmpfs or named volume) |

### Config file locations

- `configs/settings.yml` — Main settings file (generated on first run if not present)
- `configs/custom_settings.yml` — User-specific/custom settings overrides
- `configs/server-certificate.p12` — Auto-generated server certificate for PDF signing (if enabled)
- `configs/stirling-pdf-DB-<version>.mv.db` — H2 database file (user data, API keys, etc.)

**Source**: https://docs.stirlingpdf.com/Installation/Path%20Structure/

### Full docker-compose example (production)

```yaml
services:
  stirling-pdf:
    image: docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest
    container_name: stirling-pdf
    ports:
      - '8080:8080'
    volumes:
      - ./stirling-data/tessdata:/usr/share/tessdata    # OCR language files
      - ./stirling-data/configs:/configs                 # Settings & database
      - ./stirling-data/logs:/logs                       # Application logs
      - ./stirling-data/customFiles:/customFiles:rw      # Custom branding files
      - ./stirling-data/pipeline:/pipeline               # Automation configs
    environment:
      - SECURITY_ENABLELOGIN=true
      - SYSTEM_DEFAULTLOCALE=en-US
      - SYSTEM_GOOGLEVISIBILITY=false
      - SYSTEM_ROOTURIPATH=/
      - SYSTEMFILEUPLOADLIMIT=2000MB
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'
```

**Source**: https://docs.stirlingpdf.com/Production-Deployment-Guide/

## Environment variables

Stirling-PDF can be fully configured via environment variables (which override `settings.yml`
values). Key environment variables:

### Core / system

| Variable | Default | Description |
|----------|---------|-------------|
| `SYSTEM_DEFAULTLOCALE` | `en-US` | Default UI locale for new users (e.g. `en-GB`, `de-DE`, `nl-NL`) |
| `SYSTEM_GOOGLEVISIBILITY` | `false` | `true` to allow Google indexing (robots.txt), `false` to hide |
| `SYSTEM_ROOTURIPATH` | `/` | Base URL path (useful for serving under a subpath, e.g. `/stirling-pdf/`) |
| `SYSTEM_APPNAME` | `Stirling-PDF` | Application display name |
| `SYSTEMFILEUPLOADLIMIT` | (varies) | Max upload size (e.g. `2000MB`). Legacy name: `SYSTEM_MAXFILESIZE` (in MB) |
| `SYSTEM_BACKENDURL` | (auto) | Public backend API URL (important for SSO/OIDC — must be publicly reachable HTTPS) |
| `SYSTEM_SERVERCERTIFICATE_ENABLED` | `true` | Enable auto-generation of server certificate for PDF signing |

### Security / authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `SECURITY_ENABLELOGIN` | `true` | Enable/disable login. **Default is ON** in standard/fat Docker images. |
| `SECURITY_LOGINMETHOD` | `all` | `all` (username+OAuth), `normal` (username only), `oauth2` (SSO only), `saml2` (SAML only) |
| `SECURITY_INITIALLOGIN_USERNAME` | `admin` | Initial admin username |
| `SECURITY_INITIALLOGIN_PASSWORD` | `stirling` | Initial admin password (**must change on first login**) |
| `DISABLE_ADDITIONAL_FEATURES` | `false` | Set to `false` to keep auth + additional features. Ultra-lite defaults differently. |
| `SECURITY_LOGINATTEMPTCOUNT` | `5` | Failed login attempts before account lock |
| `SECURITY_LOGINRESETTIMEMINUTES` | `10` | Minutes before locked account auto-unlocks |

### OAuth2 / OIDC SSO (Server tier)

| Variable | Description |
|----------|-------------|
| `SECURITY_OAUTH2_ENABLED` | Enable OAuth2 SSO (`true`/`false`) |
| `SECURITY_OAUTH2_ISSUER` | OIDC issuer URI (for Keycloak, Authentik, generic OIDC) |
| `SECURITY_OAUTH2_CLIENTID` | OAuth client ID (for generic/keycloak/authentik) |
| `SECURITY_OAUTH2_CLIENTSECRET` | OAuth client secret |
| `SECURITY_OAUTH2_CLIENT_GOOGLE_CLIENTID` | Google-specific client ID |
| `SECURITY_OAUTH2_CLIENT_GOOGLE_CLIENTSECRET` | Google-specific client secret |
| `SECURITY_OAUTH2_CLIENT_GITHUB_CLIENTID` | GitHub-specific client ID |
| `SECURITY_OAUTH2_CLIENT_GITHUB_CLIENTSECRET` | GitHub-specific client secret |
| `SECURITY_OAUTH2_PROVIDER` | Provider name: `google`, `github`, `keycloak`, `authentik`, or custom |
| `SECURITY_OAUTH2_SCOPES` | OAuth scopes (e.g. `openid, profile, email`) |
| `SECURITY_OAUTH2_USEASUSERNAME` | Claim to use as username (e.g. `email`, `preferred_username`, `login`) |
| `SECURITY_OAUTH2_AUTOCREATEUSER` | Auto-create users on first SSO login (`true`/`false`) |
| `SECURITY_OAUTH2_BLOCKREGISTRATION` | Block new user registration via SSO (`true`/`false`) |

> **Note**: OAuth2/OIDC SSO requires a **Server tier license** (paid). SAML SSO requires
> **Enterprise tier**. See `security.md` and `integration.md` for details.

### UI / customization

| Variable | Description |
|----------|-------------|
| `UI_APPNAME` | Application name shown in UI |
| `UI_HOMEDESCRIPTION` | Homepage description text |
| `UI_NAVBARLOGO` | Custom navbar logo path |

### Java / performance tuning

| Variable | Description |
|----------|-------------|
| `JAVA_TOOL_OPTIONS` | Standard JVM options (e.g. `-Xms512m -Xmx4g`) |
| `JAVA_CUSTOM_OPTS` | Custom Java system properties (used for Prometheus/Actuator config) |

### Legal / disclaimer

| Variable | Description |
|----------|-------------|
| `LEGAL_LOGINAGREEMENT_ENABLED` | Show login agreement/disclaimer dialog |
| `LEGAL_LOGINAGREEMENT_SHOWINANONYMOUSMODE` | Show disclaimer when login is disabled |
| `LEGAL_LOGINAGREEMENT_FALLBACKTEXT` | Markdown fallback text for disclaimer |

**Sources**:
- https://docs.stirlingpdf.com/Configuration/Security/System%20and%20Security/
- https://docs.stirlingpdf.com/Configuration/Security/OAuth%20SSO%20Configuration/
- https://docs.stirlingpdf.com/Production-Deployment-Guide/

## Health check endpoint

Yes — Stirling-PDF exposes a health/status endpoint:

```
GET /api/v1/info/status
```

Returns application status and version information. The official docker-compose examples use this
for health checks:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8080${SYSTEM_ROOTURIPATH:-''}/api/v1/info/status | grep -q 'UP'"]
  interval: 5s
  timeout: 10s
  retries: 16
```

Additionally, Spring Boot Actuator endpoints are available (when configured):
- `/actuator/health` — Spring Boot health endpoint
- `/actuator/info` — Application info

**Source**: https://github.com/Stirling-Tools/Stirling-PDF/blob/main/docker/embedded/compose/docker-compose-latest-security-remote-uno.yml

## Prometheus metrics

Yes — Stirling-PDF supports Prometheus metrics, but it requires:

1. An **Enterprise tier license**
2. Enterprise mode enabled
3. Additional features enabled (`DISABLE_ADDITIONAL_FEATURES=false`)

### Configuration

Via `JAVA_CUSTOM_OPTS` environment variable:

```bash
JAVA_CUSTOM_OPTS="-Dmanagement.endpoints.web.exposure.include=prometheus,health,info -Dmanagement.endpoint.health.show-details=always -Dmanagement.metrics.export.prometheus.enabled=true -Denterprisemanagement.metrics.enabled=true"
```

Or via `/configs/custom_settings.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: prometheus,health,info
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
enterprisemanagement:
  metrics:
    enabled: true
```

### Metrics endpoint

```
GET /actuator/prometheus
```

Returns metrics in Prometheus text format. Available metric types:
- **JVM metrics**: memory usage, garbage collection, thread utilization
- **System metrics**: CPU usage, file descriptors
- **Application metrics**: request rates, processing times
- **PDF processing metrics**: document operations, conversion statistics

### Prometheus scrape config

```yaml
scrape_configs:
  - job_name: 'stirling-pdf'
    metrics_path: '/actuator/prometheus'
    scrape_interval: 15s
    static_configs:
      - targets: ['your-stirling-pdf-host:port']
```

> **Note for the target environment**: Prometheus metrics require an Enterprise license. If only
> using the free tier, the non-persistent usage monitoring API endpoints (`/api/v1/info/status`,
> `/api/v1/info/requests`, etc.) are available without a license.

**Source**: https://docs.stirlingpdf.com/Configuration/Automation/Usage%20Monitoring/

## Resource requirements (RAM/CPU)

PDF processing is memory-intensive — a single large PDF can expand to many times its file size in
memory during processing.

### Minimum requirements

- **RAM**: 2 GB minimum (4 GB+ recommended)
- **CPU**: 2 cores (4+ recommended)
- **Disk**: 10 GB free space (5 GB for minimal)
- **Docker Engine**: 20.10+

### Recommended by team size

| Team size | CPU | RAM | Disk | Notes |
|-----------|-----|-----|------|-------|
| Small (1-10 users) | 2 cores (4+ rec) | 4 GB | 10 GB | Default settings work well |
| Medium (10-50 users) | 4-8 cores | 8-16 GB | 50 GB SSD | Tune LibreOffice session limits |
| Large (100+ users) | 8+ cores | 16-32 GB | 100+ GB SSD | Multiple instances + load balancer, external PostgreSQL |

### Memory behavior by file size

| File size | Strategy | Memory impact |
|-----------|----------|---------------|
| Up to 10 MB | Loaded entirely into memory | Fast, proportional to file size |
| 10-50 MB | Partially in memory, remainder on disk | Moderate |
| Over 50 MB | Fully stored on disk during processing | Minimal memory, needs disk space |

The app monitors memory pressure — if available memory drops too low, all operations are forced into
disk-backed mode.

### JVM tuning

For fine-tuning, use `JAVA_TOOL_OPTIONS`:

```yaml
environment:
  JAVA_TOOL_OPTIONS: "-Xms512m -Xmx4g"
```

If using Docker memory limits, set the container limit to **at least 1.5x the `-Xmx` value** to
leave room for LibreOffice and Tesseract background processes.

**Source**: https://docs.stirlingpdf.com/Configuration/Operations/Performance-Optimization/

## Database / statelessness

Stirling-PDF is **stateful, file-based by default** — it does **not** require an external database
for basic operation.

- **Default database**: Embedded **H2 database** (file-based), stored at
  `configs/stirling-pdf-DB-<version>.mv.db` inside the `/configs` volume.
- The H2 database stores user accounts, API keys, and usage data.
- **Back up the `/configs` volume regularly** — it contains both settings and the database.

### External database (paid feature)

- **External PostgreSQL** database support is available as a **Server/Enterprise tier** (paid)
  feature, recommended for large organizations or multi-instance deployments.
- For a single-instance small deployment, the embedded H2 database is sufficient.

**Sources**:
- https://docs.stirlingpdf.com/Configuration/Storage/DATABASE/
- https://docs.stirlingpdf.com/Configuration/Storage/External%20Database/

## Secrets / API keys

### Default credentials

- **Username**: `admin`
- **Password**: `stirling`
- Users are **forced to change the password on first login**.
- Custom initial credentials can be set via `SECURITY_INITIALLOGIN_USERNAME` and
  `SECURITY_INITIALLOGIN_PASSWORD` environment variables.

### API keys

- Each user has a unique API key (found in Account Settings in the UI).
- API authentication uses the `X-API-KEY` header:
  ```
  X-API-KEY: your-api-key-here
  ```

### Secrets needed for deployment

| Secret | Purpose | Required? |
|--------|---------|-----------|
| Initial admin password | Set via `SECURITY_INITIALLOGIN_PASSWORD` | Recommended (otherwise default `stirling` is used and must be changed on first login) |
| OAuth2 client secret | For SSO via OIDC | Only if using OAuth2 SSO (Server tier) |
| SAML keystore/cert | For SAML SSO | Only if using SAML SSO (Enterprise tier) |
| Enterprise/Server license key | To unlock paid features (SSO, external DB, metrics) | Only if using paid features |

> **For the target environment**: If running on the free tier (≤5 users) with built-in login, the
> only secret needed is the initial admin password. If integrating with Authelia via OAuth2/OIDC,
> an OAuth client secret is also needed (requires Server tier license).
