# AI Dashboard Integration

This directory contains the integration of the [ai-dashboard](https://github.com/levonk/ai-dashboard) project as external containers for the infrahub infrastructure.

## Overview

The ai-dashboard project provides comprehensive analytics for AI usage across multiple dimensions:
- AI clients (Claude Code, Codex, Pi, Devin, etc.)
- AI model suppliers (Anthropic, OpenAI, Google, Microsoft, AWS, OpenRouter, etc.)
- Models, input types, and pipeline stages
- Multi-dimensional analytics with real-time dashboards

## Architecture

This integration uses the ai-dashboard project as external containers:

- **ai-dashboard-proxy-1**: Entry stage analytics proxy (first stage in pipeline)
- **ai-dashboard-proxy-2**: Pre-egress stage analytics proxy (second-to-last stage in pipeline)
- **privacy-orchestrator**: PII detection and transformation service (second stage in pipeline)
- **ai-dashboard-db**: PostgreSQL database for analytics storage
- **ai-dashboard-web**: Next.js web application for dashboards (optional)

## Pipeline Integration

The AI Dashboard is integrated into a multi-stage analytics pipeline:

```
AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
        (Entry)              (PII Detection)    (Compression)   (Routing)       (Pre-Egress)    (Security)    (Privacy)
```

**Privacy Orchestrator**: The Privacy Orchestrator service (ai-privacy-proxy) provides PII detection and transformation capabilities between the entry stage proxy and Headroom compression. This ensures that PII is detected and transformed before data leaves the system.

See [PIPELINE.md](PIPELINE.md) for detailed pipeline architecture and configuration.

## Replacement Note

This service replaces the incomplete `ai-analytics` Python-based collectors that were previously in this directory. The ai-dashboard project is significantly more complete (88% vs 24% completion) and provides a more robust, production-ready solution.

## Configuration

Environment variables (set in `.env` or docker-compose override):

```bash
# AI Dashboard Proxy
AI_DASHBOARD_PROXY_CONTAINER_IP=172.28.0.10
AI_DASHBOARD_PROXY_HOST_PORT=8080
AI_DASHBOARD_PROXY_CONTAINER_PORT=8080
AI_DASHBOARD_LOG_LEVEL=INFO
AI_ANALYTICS_PROXY_MODE=analytics

# AI Dashboard Database
AI_DASHBOARD_DB_CONTAINER_IP=172.28.0.20
AI_DASHBOARD_DB_NAME=analytics
AI_DASHBOARD_DB_USER=postgres
AI_DASHBOARD_DB_PASSWORD=postgres
AI_DASHBOARD_DATABASE_URL=postgresql://postgres:postgres@ai-dashboard-db:5432/analytics
```

## Deployment

### Local Development

For local development, ensure all dependent services are running:
- Privacy Orchestrator service (ai-privacy-proxy)
- Headroom service
- OmniRoute service
- Iron-Proxy service
- NordVPN service

### Cloud Deployment (OCI)

For deployment to the Levonk OCI cloud server, use the Ansible playbook:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

For Privacy Orchestrator specific deployment:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-privacy-orchestrator.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Usage

### Start services

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-dashboard-pipeline up -d
```

### View logs

```bash
# Entry stage collector
docker logs ai-dashboard-proxy-1 --tail=50 -f

# Privacy Orchestrator
docker logs privacy-orchestrator --tail=50 -f

# Pre-egress stage collector
docker logs ai-dashboard-proxy-2 --tail=50 -f

# Database
docker logs ai-dashboard-db --tail=50 -f
```

### Access dashboard

- **Entry Stage API**: http://localhost:9081
- **Privacy Orchestrator API**: http://localhost:9090
- **Pre-Egress Stage API**: http://localhost:9082
- **Health checks**:
  - Entry stage: http://localhost:9081/health
  - Privacy Orchestrator: http://localhost:9090/health
  - Pre-egress stage: http://localhost:9082/health

## Development

The ai-dashboard project is located at `~/p/gh/levonk/ai-dashboard`. For development:

```bash
cd ~/p/gh/levonk/ai-dashboard
devbox run just dev
```

## License

The ai-dashboard project is dual-licensed:
- **AGPL 3.0** for open-source use
- **Commercial license** for multi-tenant, white-label, or proprietary use

See the ai-dashboard project for full license details.
