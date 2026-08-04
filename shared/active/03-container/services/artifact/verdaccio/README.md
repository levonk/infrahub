# Verdaccio Artifact Service

This directory is retained for reference only. Verdaccio is now **Ansible-managed**
via `roles/artifact-verdaccio/`, deployed from the upstream image
`verdaccio/verdaccio:latest` (multi-arch amd64 + arm64) with config templates
rendered by Ansible.

The old custom Dockerfile (`docker/Dockerfile.verdaccio`) and entrypoint
(`assets/entrypoint-verdaccio.sh`) have been removed — they are no longer needed
now that the upstream image is used directly.

## Remaining Layout

- `docker/` — Empty (Dockerfile removed; upstream image used instead).
- `healthcheck/` — Probes or scripts that validate registry availability.
- `internal-docs/` — Operational notes, SOPs, and troubleshooting guides.
- `assets/` — Empty (entrypoint removed; upstream entrypoint used instead).
- `mounts/` — Files mounted into the container at runtime (configuration, credentials, etc.).
