# Sonatype Nexus Repository

- **Repo**: https://github.com/sonatype/nexus-public
- **License**: EPL 1.0 | **Stars**: 2.6K | **Latest**: 3.94.0 (July 2026)
- **Image**: `sonatype/nexus3` — multi-arch but ~500MB+

## Why not for this use case

- **Resource footprint**: 8GB RAM minimum (small profile). The OCI ARM64 instance is too small.
- **Database required**: PostgreSQL for production. Adds infrastructure complexity.
- **Overkill**: Supports 25+ package formats (Maven, Docker, PyPI, etc.). Only npm is needed here.
- **Config complexity**: Web UI + database + JVM tuning. Not suitable for simple proxy+publish.

## Verdict

Only consider if multi-format support (Maven, Docker, PyPI) is needed. For npm-only, Verdaccio is far better suited.
