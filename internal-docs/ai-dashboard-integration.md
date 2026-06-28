# AI Dashboard Integration

## Overview

The infrahub project now uses the [ai-dashboard](https://github.com/levonk/ai-dashboard) project for AI analytics instead of the incomplete Python-based AI Analytics Pipeline.

## Replacement Details

### Previous Implementation (DEPRECATED)

- **Project**: AI Analytics Pipeline (Python-based)
- **Status**: 24% complete (8/33 stories done)
- **Architecture**: Complex 4-service setup (collectors + queue + processor + API)
- **Technology**: Python collectors, PostgreSQL, Redis
- **Location**: Previously at `~/p/gh/levonk/infrahub/shared/active/03-container/ai-analytics/`
- **Documentation**: Moved to `~/p/gh/levonk/infrahub/internal-docs/deprecated/`

### New Implementation (ACTIVE)

- **Project**: AI Dashboard (Rust-based)
- **Status**: 88% complete (15/17 stories done) - Production Ready
- **Architecture**: Simpler 2-service architecture (proxy + web)
- **Technology**: Rust proxy (high performance), Next.js web, PostgreSQL
- **Location**: External containers at `~/p/gh/levonk/infrahub/shared/active/03-container/services/ai-dashboard/`
- **Source Project**: `~/p/gh/levonk/ai-dashboard`

## Advantages of AI Dashboard

1. **Much More Complete**: 88% vs 24% completion - production-ready
2. **Simpler Architecture**: 2-service vs 4-service reduces operational complexity
3. **Better Technology Stack**: Rust performance vs Python, modern Next.js vs custom dashboard
4. **Comprehensive Analytics**: Multi-dimensional (clients, providers, models, pipeline stages, input types)
5. **AI Agent Integration**: ToonFormat for efficient AI-to-service data exchange
6. **Multi-Output Support**: HTML for humans + Markdown/ToonFormat for AI agents
7. **Advanced Features**: Alerting, cost calculation, aggregation, filtering, time-series analysis
8. **Dual Licensing**: AGPL 3.0 open-source + commercial for enterprise features

## Integration Details

### Services

- **ai-dashboard-proxy**: Rust-based analytics proxy service
  - Container IP: 172.28.0.10
  - Host Port: 8080
  - Mode: Analytics mode for data collection

- **ai-dashboard-db**: PostgreSQL database for analytics storage
  - Container IP: 172.28.0.20
  - Database: analytics
  - User: postgres

### Configuration

Environment variables (set in `.env` or docker-compose override):

```bash
# AI Dashboard Proxy
AI_DASHBOARD_PROXY_CONTAINER_IP=172.28.0.10
AI_DASHBOARD_PROXY_HOST_PORT=8080
AI_DASHBOARD_PROXY_CONTAINER_PORT=8080
AI_DASHBOARD_LOG_LEVEL=INFO
AI_DASHBOARD_MODE=analytics

# AI Dashboard Database
AI_DASHBOARD_DB_CONTAINER_IP=172.28.0.20
AI_DASHBOARD_DB_NAME=analytics
AI_DASHBOARD_DB_USER=postgres
AI_DASHBOARD_DB_PASSWORD=postgres
AI_DASHBOARD_DATABASE_URL=postgresql://postgres:postgres@ai-dashboard-db:5432/analytics
```

### Usage

#### Start services

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-dashboard up -d
```

#### View logs

```bash
docker logs ai-dashboard-proxy --tail=50 -f
docker logs ai-dashboard-db --tail=50 -f
```

#### Access dashboard

- **Proxy API**: http://localhost:8080
- **Health check**: http://localhost:8080/health

### Development

The ai-dashboard project is located at `~/p/gh/levonk/ai-dashboard`. For development:

```bash
cd ~/p/gh/levonk/ai-dashboard
devbox run just dev
```

## Migration Timeline

- **2025-06-22**: Removed incomplete Python-based collectors
- **2025-06-22**: Added ai-dashboard external containers configuration
- **2025-06-22**: Updated docker-compose.localnet.yml to include ai-dashboard
- **2025-06-22**: Moved deprecated documentation to internal-docs/deprecated/
- **2025-06-22**: Updated all task files with deprecation notices
- **2025-06-22**: Fixed Docker container configuration for proxy service
- **2025-06-22**: Updated ai-dashboard Dockerfile with proper runtime configuration

## Future Development

All future analytics development should use the ai-dashboard project:

1. **Feature Requests**: Submit to ai-dashboard project
2. **Bug Reports**: Submit to ai-dashboard project
3. **Contributions**: Follow ai-dashboard contribution guidelines
4. **Configuration**: Update ai-dashboard environment variables in infrahub

## License

The ai-dashboard project is dual-licensed:
- **AGPL 3.0** for open-source use
- **Commercial license** for multi-tenant, white-label, or proprietary use

See the ai-dashboard project for full license details.

## References

- **AI Dashboard Project**: https://github.com/levonk/ai-dashboard
- **AI Dashboard PRD**: `~/p/gh/levonk/ai-dashboard/docs/feature/prd-multi-tenant-ai-analytics.md`
- **AI Dashboard Tasks**: `~/p/gh/levonk/ai-dashboard/internal-docs/feature/prd-multi-tenant-ai-analytics/tasks/index-prd-multi-tenant-ai-analytics.md`
- **Deprecated PRD**: `~/p/gh/levonk/infrahub/internal-docs/deprecated/prd-ai-analytics-pipeline.md`
- **Deprecated Tasks**: `~/p/gh/levonk/infrahub/internal-docs/deprecated/prd-ai-analytics-pipeline/tasks/index-prd-ai-analytics-pipeline.md`
- **Integration Config**: `~/p/gh/levonk/infrahub/shared/active/03-container/services/ai-dashboard/`
- **Docker Compose**: `~/p/gh/levonk/infrahub/shared/active/03-container/docker-compose.localnet.yml`
