# Artifactory OSS

- **Repo**: https://github.com/jfrog/artifactory-docker-examples
- **License**: Open-source edition | **Backing**: JFrog (commercial)
- **Image**: `releases-docker.jfrog.io/jfrog/artifactory-oss` — multi-arch but ~500MB+

## Why not for this use case

- **Resource footprint**: 6GB RAM minimum (4 cores). Too heavy for the OCI ARM64 instance.
- **Database required**: PostgreSQL for production.
- **Overkill**: Supports 25+ package formats. Only npm is needed here.
- **SAML/OAuth not in OSS**: Would require commercial license for SSO features.
- **Config complexity**: Web UI + database + JVM tuning.

## Verdict

Only consider if multi-format support or enterprise features are needed. For npm-only, Verdaccio is far better suited.
