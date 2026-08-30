# Stirling-PDF — Traefik + Authelia Integration

Target environment: Traefik reverse proxy + Authelia SSO, on the `nl.levonk.com` network.

## Architecture overview

```
User → Traefik (TLS termination, routing) → Authelia (auth gate) → Stirling-PDF (port 8080)
```

There are **two integration approaches** for Stirling-PDF with Authelia:

### Approach A: Authelia as an auth gate (proxy-level auth) — Free tier

Authelia intercepts requests at the Traefik level and authenticates the user before forwarding to
Stirling-PDF. Stirling-PDF itself runs with login **disabled**
(`SECURITY_ENABLELOGIN=false`).

**Pros**:
- Works on the **free tier** (no paid license needed).
- Single source of truth for authentication (Authelia).
- No duplicate login screens.

**Cons**:
- Stirling-PDF's internal user/API key system is disabled — all users share the same unauthenticated
  internal access.
- API access cannot be per-user authenticated via Stirling's own API keys (would need to handle API
  auth at the proxy level or via a separate mechanism).
- Role-based access control within Stirling-PDF is not available.

### Approach B: Stirling-PDF native OAuth2/OIDC SSO with Authelia as IdP — Server tier

Authelia acts as an **OIDC identity provider**, and Stirling-PDF uses its native OAuth2/OIDC SSO
support to authenticate users. Stirling-PDF login is **enabled**
(`SECURITY_ENABLELOGIN=true`, `SECURITY_LOGINMETHOD=oauth2` or `all`).

**Pros**:
- Per-user identity within Stirling-PDF (each SSO user gets an account, API key, etc.).
- Role-based access control and per-user API keys work.
- Audit logging (Enterprise tier) ties actions to authenticated users.

**Cons**:
- Requires a **Server tier license** (paid) for OAuth2/OIDC SSO.
- More complex setup (OIDC client registration in Authelia, callback URLs, etc.).

## Approach A: Authelia auth gate (recommended for free tier)

### Traefik configuration

Stirling-PDF is a standard HTTP backend on port 8080. Configure Traefik with:

1. **HTTP router** for the Stirling-PDF hostname (e.g., `pdf.nl.levonk.com`).
2. **TLS cert resolver** (e.g., Let's Encrypt).
3. **Authelia middleware** (forward-auth) applied to the router.
4. **Service** pointing to the Stirling-PDF container on port 8080.

#### Docker labels (if using Docker provider)

```yaml
services:
  stirling-pdf:
    image: docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest
    container_name: stirling-pdf
    # Do NOT expose ports directly — Traefik handles routing
    # ports:
    #   - "8080:8080"
    networks:
      - proxy  # same network as Traefik
    volumes:
      - stirling-data:/configs
      - stirling-logs:/logs
    environment:
      - SECURITY_ENABLELOGIN=false
      - DISABLE_ADDITIONAL_FEATURES=false
      - SYSTEM_GOOGLEVISIBILITY=false
      - SYSTEM_DEFAULTLOCALE=en-US
      - SYSTEM_ROOTURIPATH=/
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.stirling-pdf.rule=Host(`pdf.nl.levonk.com`)"
      - "traefik.http.routers.stirling-pdf.entrypoints=websecure"
      - "traefik.http.routers.stirling-pdf.tls.certresolver=letsencrypt"
      - "traefik.http.routers.stirling-pdf.middlewares=authelia@docker"
      - "traefik.http.services.stirling-pdf.loadbalancer.server.port=8080"
    restart: unless-stopped

networks:
  proxy:
    external: true  # Traefik's external network

volumes:
  stirling-data:
  stirling-logs:
```

### Authelia configuration

In Authelia, create an access control rule that requires authentication for the Stirling-PDF
hostname:

```yaml
access_control:
  rules:
    - domain: 'pdf.nl.levonk.com'
      policy: one_factor  # or two_factor depending on your security requirements
```

### Important: X-Forwarded headers

Traefik automatically sends `X-Forwarded-For`, `X-Forwarded-Proto`, and `X-Forwarded-Host` headers.
Stirling-PDF (Spring Boot) respects these standard forwarded headers.

**Critical**: When behind a reverse proxy, ensure:
- `X-Forwarded-Proto: https` is passed (Traefik does this by default) — so Stirling-PDF knows it's
  serving over HTTPS even though it listens on HTTP internally.
- This is especially important for OAuth2 callback URLs and for the `system.backendUrl` setting.

### X-Frame-Options

If Authelia or any other service needs to embed Stirling-PDF in an iframe, set:
```yaml
system:
  xFrameOptions: SAMEORIGIN
```
Otherwise, keep the default `DENY` for security.

## Approach B: Native OAuth2/OIDC SSO with Authelia as IdP (Server tier)

### Prerequisites

1. **Server tier license** for Stirling-PDF (paid).
2. Authelia configured as an **OIDC provider** (Authelia supports OIDC since v4.29+).
3. Public HTTPS URL for Stirling-PDF (e.g., `https://pdf.nl.levonk.com`).

### Step 1: Register an OIDC client in Authelia

In Authelia's configuration, create an OIDC client for Stirling-PDF:

```yaml
identity_providers:
  oidc:
    clients:
      - client_id: stirling-pdf
        client_name: Stirling-PDF
        client_secret: <hashed-secret>  # use Authelia's password hash
        public: false
        authorization_policy: two_factor
        redirect_uris:
          - https://pdf.nl.levonk.com/login/oauth2/code/authelia
        scopes:
          - openid
          - profile
          - email
        userinfo_signing_algorithm: none
```

> **Note**: The redirect URI **must** match exactly: `https://pdf.nl.levonk.com/login/oauth2/code/<provider>`.
> The `<provider>` value is what you set in `SECURITY_OAUTH2_PROVIDER`.

### Step 2: Configure Stirling-PDF for OIDC with Authelia

```yaml
services:
  stirling-pdf:
    image: docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest
    environment:
      - SECURITY_ENABLELOGIN=true
      - SECURITY_LOGINMETHOD=all  # or oauth2 for SSO-only
      - SECURITY_OAUTH2_ENABLED=true
      - SECURITY_OAUTH2_ISSUER=https://auth.nl.levonk.com  # Authelia OIDC issuer
      - SECURITY_OAUTH2_CLIENTID=stirling-pdf
      - SECURITY_OAUTH2_CLIENTSECRET=<your-client-secret>
      - SECURITY_OAUTH2_PROVIDER=authelia  # custom provider name
      - SECURITY_OAUTH2_SCOPES=openid, profile, email
      - SECURITY_OAUTH2_USEASUSERNAME=preferred_username
      - SECURITY_OAUTH2_AUTOCREATEUSER=true
      - SECURITY_OAUTH2_BLOCKREGISTRATION=false
      - SYSTEM_BACKENDURL=https://pdf.nl.levonk.com
```

> **Important**: `SYSTEM_BACKENDURL` (or `system.backendUrl` in settings.yml) must be set to the
> public HTTPS URL. Stirling-PDF needs to know its public URL for OAuth2 callback generation.
> Verify `https://pdf.nl.levonk.com/api/v1/info/status` is accessible.

### Step 3: Traefik configuration (no Authelia middleware)

When using native SSO, you do **not** apply the Authelia forward-auth middleware to the Stirling-PDF
router — Stirling-PDF handles authentication itself via OAuth2 redirect to Authelia.

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.stirling-pdf.rule=Host(`pdf.nl.levonk.com`)"
  - "traefik.http.routers.stirling-pdf.entrypoints=websecure"
  - "traefik.http.routers.stirling-pdf.tls.certresolver=letsencrypt"
  # NO authelia middleware here — Stirling-PDF handles auth via OAuth2 redirect
  - "traefik.http.services.stirling-pdf.loadbalancer.server.port=8080"
```

### OAuth2 flow

1. User navigates to `https://pdf.nl.levonk.com`.
2. Stirling-PDF (with login enabled) redirects to Authelia's OIDC authorization endpoint.
3. User authenticates with Authelia (password + 2FA).
4. Authelia redirects back to `https://pdf.nl.levonk.com/login/oauth2/code/authelia` with auth code.
5. Stirling-PDF exchanges code for tokens, retrieves user info, creates/looks up local user.
6. User is logged in to Stirling-PDF.

## Special header / forwarding requirements

### Standard forwarded headers

Traefik automatically handles:
- `X-Forwarded-For` — client IP
- `X-Forwarded-Proto` — original protocol (https)
- `X-Forwarded-Host` — original host
- `X-Forwarded-Port` — original port

Stirling-PDF (Spring Boot) respects these via standard `ForwardedHeaderFilter`. No special
configuration needed beyond ensuring Traefik is configured as the entrypoint.

### Trusting proxy headers

Spring Boot needs to trust the proxy headers. This is typically handled automatically when the app
detects it's running behind a proxy. If issues arise with redirect URLs showing `http://` instead of
`https://`, you may need to configure the server's forwarded header trust. Check if
`server.forward-headers-strategy` needs to be set (Spring Boot native setting, can be passed via
`JAVA_CUSTOM_OPTS`):

```bash
JAVA_CUSTOM_OPTS="-Dserver.forward-headers-strategy=NATIVE"
```

### Root URI path (subpath deployment)

If serving Stirling-PDF under a subpath (e.g., `https://nl.levonk.com/pdf/`), set:

```bash
SYSTEM_ROOTURIPATH=/pdf
```

This affects all internal URLs, health check paths, and OAuth2 callback paths. The health check
would then be at `/pdf/api/v1/info/status`.

For the target environment, a **dedicated subdomain** (e.g., `pdf.nl.levonk.com`) is simpler and
recommended over a subpath — avoids path rewriting complexity in Traefik.

## Summary: recommended approach for nl.levonk.com

| Aspect | Approach A (Authelia gate) | Approach B (Native OIDC) |
|--------|---------------------------|--------------------------|
| License needed | Free tier | Server tier (paid) |
| Auth mechanism | Authelia forward-auth middleware | Stirling-PDF OAuth2 → Authelia OIDC |
| Stirling login | Disabled | Enabled (oauth2 or all) |
| Per-user API keys | No | Yes |
| User auto-provisioning | N/A (no internal users) | Yes (via `AUTOCREATEUSER`) |
| Complexity | Low | Medium |
| Traefik middleware | `authelia@docker` | None (Stirling handles redirect) |
| Best for | Simple shared PDF tools for trusted users | Organizations needing per-user tracking, API keys, audit logs |

**Recommendation**: Start with **Approach A** (Authelia auth gate) for simplicity and zero licensing
cost. If per-user API keys, audit logging, or role-based access within Stirling-PDF are needed
later, upgrade to a Server tier license and switch to **Approach B** (native OIDC with Authelia as
IdP).

## Health check behind Traefik

For Docker health checks (internal to the container), use the internal endpoint:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8080/api/v1/info/status | grep -q 'UP'"]
  interval: 30s
  timeout: 10s
  retries: 3
```

For Traefik health checks (if configured), the external endpoint would be:
`https://pdf.nl.levonk.com/api/v1/info/status`

> **Note**: If using Approach A (Authelia gate), the status endpoint will be behind auth. Either
> exclude `/api/v1/info/status` from the Auth middleware in Traefik, or use internal container
> health checks only.
