# career-jobops

Deploys [JobOps](https://github.com/DaKheera47/job-ops) — a job hunting tool that
searches 10+ job boards, scores jobs against your profile, tailors your CV, and
tracks applications.

## Architecture

- **Image**: Upstream GHCR (`ghcr.io/dakheera47/job-ops:latest`) — no build phase
- **Target**: Windows Docker Desktop hosts (via named pipe)
- **Traefik routing**: Cross-machine — Traefik on OCI routes to the Windows
  machine's Tailscale FQDN + host port (not a container name, since the
  container is on a different Docker host)

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jobops_enabled` | `true` | Enable flag |
| `jobops_container_name` | `localnet-jobops` | Container name |
| `jobops_image_name` | `ghcr.io/dakheera47/job-ops` | GHCR image |
| `jobops_image_tag` | `latest` | Image tag |
| `jobops_host_port` | `{{ infra_port_career_jobops_host }}` | Host port (3005) |
| `jobops_container_port` | `{{ infra_port_career_jobops_container }}` | Container port (3001) |
| `jobops_domain` | `{{ infra_domain_career_jobops }}` | Public domain |
| `jobops_data_volume` | `{{ infra_storage_jobops_data_volume }}` | Data volume |
| `jobops_codex_volume` | `{{ infra_storage_jobops_codex_volume }}` | Codex CLI volume |

## Secrets

No vault secrets required. AI provider API keys are configured via the onboarding
wizard (stored in the data volume).
