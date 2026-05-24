# Verdaccio Artifact Service

This directory manages the Verdaccio npm proxy that ships with Homelab In-a-Box. The structure mirrors the Nexus layout so every service is easy to navigate.

## Layout

- `docker/` — Dockerfiles and helper scripts used to customize the Verdaccio image.
- `healthcheck/` — Probes or scripts that validate registry availability.
- `internal-docs/` — Operational notes, SOPs, and troubleshooting guides.
- `assets/` — Static resources bundled into the container image.
- `mounts/` — Files mounted into the container at runtime (configuration, credentials, etc.).
