# tools-stirling-pdf

Deploys [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) — a self-hosted
PDF utility suite (merge, split, convert, sign, OCR, watermark, etc.) — as a Docker
container on Windows Docker Desktop (dtop202311, nl region).

## Deployment

Target: `windows_docker_hosts` group (dtop202311).

Uses the ssh-tunneled Docker CLI pattern (`DOCKER_HOST: ssh://` + `delegate_to: localhost`)
because `community.docker` modules cannot run on Windows (Ansible core `basic.py` imports
`grp`, Unix-only).

```bash
just ansible-deploy-stirling-pdf
```

Or directly:

```bash
ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-stirling-pdf.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Architecture

- **Image**: `stirlingtools/stirling-pdf:latest` (Docker Hub, multi-arch amd64 + arm64)
- **Port**: Container 8080, host 4531 (variable: `infra_port_tools_stirling_pdf_host`)
- **Domain**: `stirling.nl.{{ infra_domain_base }}` (variable: `infra_domain_tools_stirling_pdf`)
- **Network**: `traefik-windows-network` (joined for Traefik routing)
- **Reverse proxy**: Traefik (Windows instance) with Authelia forward-auth SSO

## Volumes

| Volume | Container path | Purpose |
|--------|---------------|---------|
| configs | `/configs` | `settings.yml`, H2 file database, custom settings |
| tessdata | `/usr/share/tessdata` | OCR language data (persisted to avoid re-download) |
| pipeline | `/pipeline` | Saved pipeline definitions |
| customFiles | `/customFiles` | User-uploaded template files |
| logs | `/logs` | Application logs |

All volumes are initialized via the `localnet-volume-init` role (UID/GID 1000, mode 755)
per ADR-20260822001.

## Security

- **Auth**: Authelia forward-auth via Traefik (free tier). Stirling-PDF's internal login
  is disabled (`SECURITY_ENABLE_LOGIN=false`) so Authelia is the sole authentication gate.
- **No secrets required**: The free tier does not need API keys or vault entries.
- **no-new-privileges**: Container runs with `--security-opt no-new-privileges:true`.

## Monitoring

- **Health endpoint**: `GET /api/v1/info/status` (returns JSON with `UP` status)
- **Metrics**: `/actuator/prometheus` — requires Enterprise tier license (not enabled)
- **Pipeline**: `none` (standalone tools service, not part of AI/DNS/Web/VPN pipelines)
- **Alert labels**: `pipeline=none`, `stage=tools`, `service=stirling-pdf`

## Backup

Stirling-PDF uses a file-based H2 database (in the configs volume). The configs volume
holds all persistent state. To back up:

```bash
# On dtop202311 (via Tailscale):
docker run --rm -v localnet-stirling-pdf-configs-volume:/data:ro \
  -v /opt/localnet/backup/stirling-pdf:/backup alpine \
  tar czf /backup/stirling-pdf-configs-$(date +%F).tar.gz -C /data .
```

Only the configs volume needs backup — tessdata is regenerable, pipeline/customFiles
are user data that can be backed up with the same pattern if needed.

## Variables

See `defaults/main.yml` for all configurable variables. All ports, domains, and storage
paths reference `infra_*` infrastructure variables — no hardcoded values.
