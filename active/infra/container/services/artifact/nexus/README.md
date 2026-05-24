# Nexus Artifact Service

This directory contains deployment assets for the Sonatype Nexus Repository Manager instance that ships with Homelab In-a-Box. Each subdirectory mirrors a specific concern so we can keep Docker build context, health checks, documentation, and mounted configuration files isolated.

## Layout

- `docker/` — Custom Dockerfiles, patches, or helper scripts required to build the Nexus image.
- `healthcheck/` — Probes or scripts used to verify repository availability.
- `internal-docs/` — Runbooks and architectural notes for the Nexus service.
- `assets/` — Static assets bundled into the container image.
- `mounts/` — Files volume-mounted into the container at runtime (configuration, certificates, etc.).
