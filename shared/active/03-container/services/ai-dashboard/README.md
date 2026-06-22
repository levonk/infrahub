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

- **ai-dashboard-proxy**: Rust-based analytics proxy service
- **ai-dashboard-db**: PostgreSQL database for analytics storage
- **ai-dashboard-web**: Next.js web application for dashboards (optional)

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

## Usage

### Start services

```bash
cd /Users/micro/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-dashboard up -d
```

### View logs

```bash
docker logs ai-dashboard-proxy --tail=50 -f
docker logs ai-dashboard-db --tail=50 -f
```

### Access dashboard

- **Proxy API**: http://localhost:8080
- **Health check**: http://localhost:8080/health

## Development

The ai-dashboard project is located at `/Users/micro/p/gh/levonk/ai-dashboard`. For development:

```bash
cd /Users/micro/p/gh/levonk/ai-dashboard
devbox run just dev
```

## License

The ai-dashboard project is dual-licensed:
- **AGPL 3.0** for open-source use
- **Commercial license** for multi-tenant, white-label, or proprietary use

See the ai-dashboard project for full license details.
