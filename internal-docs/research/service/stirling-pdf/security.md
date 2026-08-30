# Stirling-PDF — Security Considerations

## Default credentials

**Login is ON by default** in the standard and fat Docker images (`security.enableLogin: true`).

A fresh container starts with a default admin account:

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `stirling` |

**Mitigation**:
- Users are **forced to change the password on first login**.
- Custom initial credentials can be set via environment variables:
  - `SECURITY_INITIALLOGIN_USERNAME`
  - `SECURITY_INITIALLOGIN_PASSWORD`
- **Always set a strong initial password** via the environment variable, or change it immediately
  after first login.

**Source**: https://docs.stirlingpdf.com/Configuration/Security/System%20and%20Security/

## Authentication modes

Stirling-PDF supports several authentication configurations via `SECURITY_LOGINMETHOD`:

| Value | Behavior |
|-------|----------|
| `all` | Username/password + OAuth2 SSO (default for SSO setup) |
| `normal` | Username/password only |
| `oauth2` | OAuth2/OIDC SSO only (disables username/password) |
| `saml2` | SAML 2.0 SSO only (Enterprise tier) |

### Disabling login entirely

If you want no authentication (e.g., behind an SSO gateway like Authelia that handles auth at the
proxy level), set:

```bash
SECURITY_ENABLELOGIN=false
DISABLE_ADDITIONAL_FEATURES=false
```

> **Warning**: Disabling login also makes the instance publicly accessible to anyone who can reach
> it. Only do this behind a reverse proxy with authentication enforced (e.g., Traefik + Authelia).

## SSO / OIDC support

### OAuth 2.0 / OpenID Connect (OIDC)

- **Tier**: **Server** (paid)
- Supports: Google, GitHub, Keycloak, Authentik, and any OIDC-compliant provider.
- Auto-discovery via `.well-known/openid-configuration`.
- Callback URL: `https://your-domain.com/login/oauth2/code/<provider>`
- Auto-create users on first SSO login (`SECURITY_OAUTH2_AUTOCREATEUSER=true`).
- Can block new registrations (`SECURITY_OAUTH2_BLOCKREGISTRATION=true`).

**Key environment variables** (see `deployment.md` for full list):
- `SECURITY_OAUTH2_ENABLED=true`
- `SECURITY_OAUTH2_ISSUER=<issuer_uri>`
- `SECURITY_OAUTH2_CLIENTID=<client_id>`
- `SECURITY_OAUTH2_CLIENTSECRET=<client_secret>`
- `SECURITY_OAUTH2_PROVIDER=<provider_name>`
- `SECURITY_OAUTH2_SCOPES=openid, profile, email`
- `SECURITY_OAUTH2_USEASUSERNAME=preferred_username`

**Prerequisite**: `system.backendUrl` must be set to the public HTTPS backend API URL. Verify
`https://your-domain.com/api/v1/info/status` is accessible.

**Source**: https://docs.stirlingpdf.com/Configuration/Security/OAuth%20SSO%20Configuration/

### SAML 2.0

- **Tier**: **Enterprise** (paid, higher than Server)
- Supports: Okta, Azure AD (Entra ID), Google Workspace, OneLogin, any SAML 2.0 IdP.
- Single Logout (SLO) support.

**Source**: https://docs.stirlingpdf.com/Configuration/Security/SAML%20SSO%20Configuration/

## Securing behind a reverse proxy

### HTTPS / TLS

Stirling-PDF itself runs plain HTTP on port 8080. TLS termination should be handled by the reverse
proxy (Traefik). The app does not natively serve HTTPS.

### X-Frame-Options

The `xFrameOptions` setting controls iframe embedding:
- `DENY` (recommended) — prevents clickjacking, blocks all iframe embedding.
- `SAMEORIGIN` — only allow embedding from same origin (use only if embedding the UI in your own
  app).

Configure via `settings.yml`:
```yaml
system:
  xFrameOptions: DENY
```

### SSRF protection

Stirling-PDF has built-in SSRF protection configurable for endpoints that accept URLs (e.g.,
HTML-to-PDF, markdown-to-PDF conversions). This is important since several past CVEs involved SSRF
(see below).

**Source**: https://docs.stirlingpdf.com/Configuration/Security/SSRF-Protection/

### Fail2Ban integration

Stirling-PDF supports Fail2Ban integration for brute-force protection on login attempts:

- `loginAttemptCount`: failed login attempts before lock (default: 5)
- `loginResetTimeMinutes`: minutes before auto-unlock (default: 10)

**Source**: https://docs.stirlingpdf.com/Configuration/Security/fail2ban/

### Audit logging

- **Tier**: Enterprise (paid)
- Provides audit logging of user actions and API calls for compliance.

**Source**: https://docs.stirlingpdf.com/Configuration/Security/Audit%20Logging/

### API key security

- Each user has a unique API key (visible in Account Settings).
- API authentication via `X-API-KEY` header.
- Treat API keys as secrets — they grant full API access for that user.
- Rotate keys if compromised (via Account Settings in UI).

### Google visibility

Set `SYSTEM_GOOGLEVISIBILITY=false` (default) to prevent search engine indexing via `robots.txt`.

### Login agreement / disclaimer

Optional disclaimer dialog shown after login (or on launch if login disabled). Configure via:
- `LEGAL_LOGINAGREEMENT_ENABLED=true`
- `LEGAL_LOGINAGREEMENT_FALLBACKTEXT="Your terms..."`

## Known CVEs / Security Advisories

Stirling-PDF maintains a public GitHub Security Advisories page. As of research date, the following
advisories have been published (this is not exhaustive — check the live page for the latest):

**Source**: https://github.com/Stirling-Tools/Stirling-PDF/security/advisories

| Advisory ID | Title | Severity | Published |
|-------------|-------|----------|-----------|
| GHSA-3xxh-mm3g-c9w5 | Internal Service Account API Key Disclosure via Pipeline Endpoint | High | Jul 2026 |
| GHSA-qc47-qgh9-xj63 | Stored XSS in Stirling PDF Info Summary | High | Jul 2026 |
| GHSA-xmhg-fv84-jgfc | Stored Cross Site Scripting (XSS) via EML-to-HTML Export | Moderate | Mar 2026 |
| GHSA-wccq-mg6x-2w22 | Path Traversal Vulnerability in /api/v1/convert/markdown/pdf Endpoint | High | Mar 2026 |
| GHSA-3932-2rfq-87xm | DoS via add-watermark | Moderate | Mar 2026 |
| GHSA-q5j3-4m5w-wp75 | Reflected XSS through crafted filename in file upload | Low | Apr 2026 |
| GHSA-rjjx-43g5-mp76 | Reflected XSS through crafted PDF metadata fields | Low | May 2026 |
| GHSA-ff33-grr6-rmvp | SSRF vulnerability on /api/v1/convert/markdown/pdf | High | Aug 2025 |
| GHSA-76hv-h7g2-xfv3 | SSRF vulnerability on /api/v1/convert/file/pdf | High | Aug 2025 |
| GHSA-xw8v-9mfm-g2pm | SSRF vulnerability on /api/v1/convert/html/pdf | High | Aug 2025 |

### Key takeaways from CVE history

1. **SSRF vulnerabilities** are a recurring theme (3 High severity in Aug 2025 alone) — ensure SSRF
   protection is enabled and the instance is not exposed to untrusted networks.
2. **XSS vulnerabilities** (stored and reflected) have been found — keep the instance updated to the
   latest version.
3. **Path traversal** vulnerability was found in the markdown-to-PDF endpoint — another reason to
   keep updated.
4. **API key disclosure** via pipeline endpoint — ensure pipelines are not exposed to untrusted
   users.

### Recommendations

- **Always pin to the latest stable version** and update regularly.
- **Keep login enabled** (`SECURITY_ENABLELOGIN=true`) unless behind an authenticated reverse proxy.
- **Enable SSRF protection** if using URL-based conversion endpoints.
- **Restrict access** to the instance via network rules / reverse proxy authentication.
- **Set `xFrameOptions: DENY`** to prevent clickjacking.
- **Set a strong initial admin password** via environment variables.
- **Disable Google visibility** (`SYSTEM_GOOGLEVISIBILITY=false`).
- **Monitor the security advisories page** for new CVEs.
