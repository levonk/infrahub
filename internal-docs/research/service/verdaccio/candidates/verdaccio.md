# Verdaccio

- **Repo**: https://github.com/verdaccio/verdaccio
- **License**: MIT | **Stars**: 17.8K | **Latest**: v6.9.0 (July 2026)
- **Image**: `verdaccio/verdaccio` — official multi-arch (amd64 + arm64), ~67MB compressed

## Fit for this use case

- **Proxy + cache**: Built-in uplinks feature. Caches npmjs.org packages locally. Configurable cache TTL.
- **Publish**: Full scoped package support (@levonk/*). Authenticated users can publish/unpublish.
- **Auth**: Built-in htpasswd/bcrypt. npm CLI compatible (`npm login` / `npm publish`). LDAP via plugin.
- **Multi-arch**: Official amd64 + arm64 images. Works on Oracle Cloud ARM64 and Windows Docker Desktop X86.
- **Footprint**: 512MB-1GB RAM. No database. JSON-based metadata.
- **Config**: Single YAML file. Ansible can render from Jinja2 templates.
- **Traefik**: Documented reverse proxy support. `VERDACCIO_PUBLIC_URL` env var. X-Forwarded-* headers.
- **Storage eviction**: No automatic LRU. Workaround: cron job or manual cleanup. Proxy cache is disposable.

## Verdict

**Perfect fit.** The only gap (storage eviction) is minor for personal use and addressable with a cron job.
