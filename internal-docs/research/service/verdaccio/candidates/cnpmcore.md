# cnpmcore / cnpmjs.org

- **Repo**: https://github.com/cnpm/cnpmcore
- **License**: MIT | **Stars**: 725 | **Latest**: 4.34.0 (June 2026)
- **Image**: No official multi-arch images (x86 only)

## Why not for this use case

- **No multi-arch Docker**: x86 only. ARM64 (Oracle Cloud) requires custom build.
- **Complex dependency stack**: MySQL + Redis + S3 required. Overkill.
- **No built-in htpasswd auth**: Bearer tokens + external LDAP service.
- **Config complexity**: JavaScript config + multiple services.

## Verdict

Only consider if advanced features (dependency isolation, package blocking) are needed and infrastructure can be provisioned. For simple proxy+publish, Verdaccio is far better suited.
