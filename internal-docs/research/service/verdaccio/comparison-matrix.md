# Private NPM Registry Comparison Matrix

Date: 2026-08-04
Use case: Dual-deployment private npm registry/proxy cache on Oracle Cloud ARM64 (cno) + Windows Docker Desktop X86 (nl), fronted by Traefik + Authelia SSO, htpasswd/bcrypt auth for npm CLI publish.

| Capability | Verdaccio | Sonatype Nexus | cnpmcore | pnpr | Artifactory OSS |
|------------|-----------|----------------|----------|------|-----------------|
| **Category Coverage** | npm only | npm, Maven, Docker, PyPI, Go, Helm, etc. (25+ formats) | npm only | npm only | npm, Maven, Docker, PyPI, Go, Helm, etc. (25+ formats) |
| **Proxy + Cache** | Yes (uplinks) | Yes (remote repositories) | Yes (source registry) | Yes (upstream registries) | Yes (remote repositories) |
| **Publish Private** | Yes (scoped packages) | Yes (hosted repositories) | Yes (scoped packages) | Yes (hosted registries) | Yes (local repositories) |
| **Auth Model** | htpasswd (built-in), LDAP plugins, token-based | LDAP, SAML, SSO, user tokens, basic auth | Bearer tokens, LDAP (via external service) | htpasswd, bearer tokens, SQL backends | LDAP, SAML, OAuth, HTTP SSO, basic auth |
| **Docker Multi-Arch** | Yes (amd64 + arm64, ~67MB) | Yes (amd64 + arm64) | No (x86 only, requires custom build) | No (Rust, needs compilation) | Yes (amd64 + arm64) |
| **Resource Footprint** | 512MB-1GB RAM minimum | 8GB RAM minimum (small profile) | MySQL + Redis required (complex) | Lightweight (Rust) | 6GB RAM minimum (4 cores) |
| **Storage Eviction** | No automatic LRU (manual unpublish) | Yes (cleanup policies + compact blob store) | Partial (blocking, no simple LRU) | Yes (separate cache, safe to wipe) | Yes (cleanup policies, retention rules) |
| **Maintenance** | Active (17.8K stars, releases every 1-10 days) | Active (2.6K stars, releases weekly) | Active (725 stars, releases monthly) | Experimental (part of pnpm) | Active (commercial backing) |
| **Config Complexity** | Low (YAML, zero database) | High (web UI, database required) | High (MySQL + Redis + S3 + config) | Medium (YAML, no database) | High (web UI, database required) |
| **Traefik Compatible** | Yes (X-Forwarded-* headers, VERDACCIO_PUBLIC_URL) | Yes (reverse proxy docs) | Unknown (likely yes) | Yes (--public-url flag) | Yes (reverse proxy docs) |

## Summary

**Verdaccio** is the best fit for the user's requirements:
- Lightweight enough for small Oracle Cloud ARM64 instance
- Multi-arch Docker support for both ARM64 and X86 deployments
- Built-in htpasswd/bcrypt auth for npm CLI publish
- Works behind Traefik with proper header support
- Simple YAML configuration, no database required
- Active development with frequent releases

The only gap is automatic LRU storage eviction, which can be addressed with a simple cron job or storage plugin.
