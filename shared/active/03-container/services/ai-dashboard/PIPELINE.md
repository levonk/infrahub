# AI Dashboard Pipeline Configuration

## Recent Changes

**2026-06-22**: Added Privacy Filter stage to pipeline architecture
- New stage between AI Dashboard Proxy 1 and Headroom
- Implements PII detection and redaction using privacy-filter.cpp
- **Status**: TO BE IMPLEMENTED - requires new proxy service project
- See "Privacy Filter Implementation" section for details

## Overview

This configuration implements a multi-stage AI analytics pipeline with comprehensive data collection at key stages. The pipeline provides deep visibility into AI usage patterns, optimization effectiveness, and security analytics.

## Pipeline Architecture

```
AI Dashboard Proxy 1 → Privacy Filter → Headroom → OmniRoute → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
        (Entry)           (PII Redaction)    (Compression)   (Routing)       (Pre-Egress)    (Security)    (Privacy)
```

### Compression Strategy

**Headroom-Primary Compression:**
- Headroom handles all compression (60-95% token savings)
- OmniRoute compression disabled to avoid redundancy
- OmniRoute focuses on intelligent provider routing
- Caveman compression available as fallback in OmniRoute if needed
- This eliminates compression redundancy and optimizes routing decisions

### Pipeline Stages

1. **AI Dashboard Proxy 1 (Entry Stage)**
   - Collects analytics on all incoming AI requests
   - Captures original request size, tokens, and metadata
   - Records client identification and request timing
   - **Port**: 8081
   - **Container IP**: 172.28.0.11
   - **Chain IP**: 172.29.0.11

2. **Privacy Filter (PII Redaction)**
   - Detects and redacts PII (Personally Identifiable Information) from AI requests
   - Uses OpenAI's privacy-filter model via privacy-filter.cpp
   - Supports 22+ PII categories across multiple languages
   - Real-time PII detection with sub-millisecond latency
   - **Implementation**: New service wrapping privacy-filter.cpp as HTTP proxy
   - **Port**: TBD (recommended: 9090)
   - **Upstream from**: AI Dashboard Proxy 1
   - **Downstream to**: Headroom
   - **Status**: **TO BE IMPLEMENTED** - requires new proxy service project

3. **Headroom (Context Compression)**
   - Compresses LLM context to reduce token usage
   - Applies RTK+Caveman stacked compression (15-95% token savings)
   - **Port**: 8787
   - **Upstream from**: Privacy Filter
   - **Downstream to**: OmniRoute

4. **OmniRoute (AI Gateway)**
   - Smart routing across 177+ AI providers (50+ free)
   - Automatic provider selection and fallback
   - Format translation between different AI APIs
   - **Compression completely disabled** (Headroom handles compression)
   - **RTK disabled** (avoids redundancy with Headroom)
   - **Caveman disabled** (avoids redundancy with Headroom)
   - **Port**: 20128
   - **Upstream from**: Headroom
   - **Downstream to**: AI Dashboard Proxy 2

5. **AI Dashboard Proxy 2 (Pre-Egress Stage)**
   - Collects analytics after routing and optimization
   - Measures compression effectiveness
   - Records provider selection and routing decisions
   - **Port**: 8082
   - **Container IP**: 172.28.0.12
   - **Chain IP**: 172.29.0.12
   - **Upstream from**: OmniRoute
   - **Downstream to**: Iron-Proxy

6. **Iron-Proxy (Egress Firewall)**
   - Default-deny egress filtering
   - Secret injection at boundary
   - Per-request audit trail
   - **Port**: 8080
   - **Upstream from**: AI Dashboard Proxy 2
   - **Downstream to**: NordVPN

7. **NordVPN (Privacy Layer)**
   - VPN tunnel for privacy and geo-obfuscation
   - Routes all egress traffic through VPN
   - **Port**: 1080
   - **Upstream from**: Iron-Proxy
   - **Downstream to**: Internet

## Analytics Dimensions

The AI Dashboard collects multi-dimensional analytics across:

- **Company Clients**: Multi-tenant client identification and isolation
- **AI Clients**: Claude Code, Codex, Pi, Devin, Cursor, Cline, etc.
- **Teams**: Team/sub-organization hierarchy within clients
- **Pipeline Stages**: Entry, compression, routing, pre-egress analytics
- **AI Model Suppliers**: Anthropic, OpenAI, Google, Microsoft, AWS, OpenRouter, etc.
- **Models**: GPT-4, Claude 3.5 Opus, Gemini Pro, etc.
- **Input Types**: Text/chat, image, audio, video, code, etc.

## Key Metrics Tracked

### Entry Stage (Proxy 1)
- Original request size and token count
- Client identification and authentication
- Request timing and latency
- Input type classification

### Privacy Filter Analytics
- PII detection rates and categories
- Redaction effectiveness metrics
- Processing latency (sub-millisecond expected)
- False positive/negative rates
- Multi-language coverage statistics

### Compression Analytics (Headroom comparison)
- Token savings percentage (Headroom: 60-95%)
- Compression ratio (measured by Headroom)
- Processing time overhead
- Context preservation metrics
- **Note**: OmniRoute compression disabled to avoid redundancy

### Routing Analytics (OmniRoute comparison)
- Provider selection patterns
- Fallback events
- Format translation overhead
- Provider performance metrics

### Pre-Egress Stage (Proxy 2)
- Optimized request size and token count
- Final provider selection
- Cost calculation
- Security classification

### Security Analytics (Iron-Proxy)
- Domain allowlist hits/blocks
- Secret injection events
- Anomaly detection
- Audit trail completeness

## Configuration Files

### docker-compose.ai-dashboard-pipeline.yml
Main Docker Compose configuration for the pipeline. Defines:
- Dual AI Dashboard proxy collectors
- Shared PostgreSQL database
- Network configuration
- Health checks and dependencies

### .env.pipeline
Environment variables for pipeline configuration:
- Database connection settings
- Collector IP addresses and ports
- Stage identification
- Upstream service URLs

## Usage

### Start the Pipeline

```bash
cd /Users/micro/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-dashboard-pipeline up -d
```

### Start with Environment File

```bash
cd /Users/micro/p/gh/levonk/infrahub/shared/active/03-container/services/ai-dashboard
docker compose -f docker-compose.ai-dashboard-pipeline.yml --env-file .env.pipeline up -d
```

### View Logs

```bash
# Entry stage collector
docker logs ai-dashboard-proxy-1 --tail=50 -f

# Privacy filter (TO BE IMPLEMENTED)
docker logs privacy-filter --tail=50 -f

# Pre-egress stage collector
docker logs ai-dashboard-proxy-2 --tail=50 -f

# Database
docker logs ai-dashboard-db --tail=50 -f
```

### Check Health

```bash
# Entry stage health
curl http://localhost:8081/health

# Privacy filter health (TO BE IMPLEMENTED)
curl http://localhost:9090/health

# Pre-egress stage health
curl http://localhost:8082/health

# Database health
docker exec ai-dashboard-db pg_isready -U postgres
```

### Access Analytics

- **Entry Stage API**: http://localhost:8081
- **Privacy Filter API**: http://localhost:9090 (TO BE IMPLEMENTED)
- **Pre-Egress Stage API**: http://localhost:8082
- **Database**: postgresql://postgres:postgres@localhost:5432/analytics

## Deployment

### Local Development

For local development, ensure all dependent services are running:
- Privacy Filter service (TO BE IMPLEMENTED)
- Headroom service
- OmniRoute service
- Iron-Proxy service
- NordVPN service

### Cloud Deployment (OCI)

For deployment to the Levonk OCI cloud server, use the Ansible playbook:
```bash
cd /Users/micro/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml --vault-password-file ~/.ansible/vault_password
```

## Network Configuration

### AI Dashboard Network
- **Name**: ai-dashboard-network
- **Type**: bridge
- **Subnet**: 172.28.0.0/16
- **Purpose**: Internal communication between collectors and database

### Proxy Chain Network
- **Name**: proxy-chain-network
- **Type**: external
- **Subnet**: 172.29.0.0/16
- **Purpose**: Communication with pipeline services (Headroom, OmniRoute, Iron-Proxy, NordVPN)

## Security Considerations

1. **PII Protection**: Privacy Filter removes PII before data leaves the system
2. **Default-Deny**: Iron-Proxy enforces default-deny egress policy
3. **Secret Injection**: Credentials injected at boundary, not in workloads
4. **Audit Trail**: Complete request logging at multiple stages
5. **VPN Privacy**: All egress traffic routed through NordVPN
6. **Data Isolation**: Multi-tenant client isolation in database schema

## Compression Strategy

**Headroom-Primary Approach:**
- **Headroom** handles all compression (60-95% token savings)
- **OmniRoute** compression completely disabled to avoid redundancy
- **OmniRoute** focuses on intelligent provider routing
- **No fallback compression** in OmniRoute (Caveman also disabled)
- **Environment Variables**:
  - `COMPRESSION_STRATEGY=headroom-primary`
  - `OMNIROUTE_COMPRESSION_ENABLED=false`
  - `OMNIROUTE_RTK_ENABLED=false`
  - `OMNIROUTE_CAVEMAN_ENABLED=false`

**Benefits:**
- Eliminates all compression redundancy between Headroom and OmniRoute
- Optimizes OmniRoute's routing decisions (works with compressed content)
- Headroom's superior compression algorithms (60-95% vs 15-95%)
- Single compression point simplifies debugging and analytics
- Cleaner separation of concerns (compression vs routing)

## Privacy Filter Implementation

### Current Status
**TO BE IMPLEMENTED** - The Privacy Filter stage is currently planned but not yet implemented.

### Implementation Requirements

A new proxy service needs to be created to wrap `privacy-filter.cpp` as an HTTP proxy service:

**Core Functionality:**
- HTTP server/proxy that intercepts AI requests
- Integration with privacy-filter.cpp C API for PII detection
- Request/response processing with PII redaction
- Support for multiple PII categories (22+ categories)
- Multi-language support (via privacy-filter-multilingual model)

**Technical Requirements:**
- HTTP proxy interface (similar to other pipeline services)
- Integration with privacy-filter.cpp C API
- Docker containerization
- Health check endpoints
- Configuration for PII sensitivity thresholds
- Logging and metrics for PII detection

**Reference Implementation:**
- Base library: https://github.com/localai-org/privacy-filter.cpp
- Pre-converted models: LocalAI-io/privacy-filter-multilingual-GGUF
- C API documentation: See `include/pf.h` in privacy-filter.cpp repository

**Recommended Architecture:**
- Rust-based proxy service (consistent with other pipeline services)
- FFI binding to privacy-filter.cpp C API
- HTTP proxy interface with request/response interception
- Configurable PII detection thresholds
- Analytics integration with AI Dashboard

### Benefits of Separate Privacy Filter Service

**Architectural:**
- Separation of concerns (privacy filtering vs analytics collection)
- Reusable across different pipelines/projects
- Independent testing and validation
- Follows microservices best practices

**Operational:**
- Can scale independently based on PII processing load
- Privacy filtering updates don't affect analytics collection
- Easier to monitor and debug PII detection issues
- Can be deployed/updated independently

**Performance:**
- Leverages privacy-filter.cpp's optimized GGML inference
- Sub-millisecond PII detection latency
- Efficient memory usage (~2.8 GiB VRAM for GPU inference)
- CPU-only option available for edge deployments

## Troubleshooting

### Pipeline Not Starting

1. Check if all dependent services are running:
   ```bash
   docker ps | grep -E "privacy-filter|headroom|omniroute|iron-proxy|nordvpn"
   ```

2. Verify network connectivity:
   ```bash
   docker network inspect proxy-chain-network
   docker network inspect ai-dashboard-network
   ```

3. Check collector logs for errors:
   ```bash
   docker logs ai-dashboard-proxy-1
   docker logs ai-dashboard-proxy-2
   ```

### Database Connection Issues

1. Verify database is running:
   ```bash
   docker ps | grep ai-dashboard-db
   ```

2. Check database logs:
   ```bash
   docker logs ai-dashboard-db
   ```

3. Test database connection:
   ```bash
   docker exec ai-dashboard-db psql -U postgres -d analytics -c "SELECT 1"
   ```

### Analytics Not Being Collected

1. Verify collectors are in analytics mode:
   ```bash
   docker exec ai-dashboard-proxy-1 env | grep AI_ANALYTICS_PROXY_MODE
   docker exec ai-dashboard-proxy-2 env | grep AI_ANALYTICS_PROXY_MODE
   ```

2. Check upstream connectivity:
   ```bash
   docker exec ai-dashboard-proxy-1 curl -f http://headroom:8787/health
   docker exec ai-dashboard-proxy-2 curl -f http://omniroute:20128/health
   ```

3. Verify database connectivity:
   ```bash
   docker exec ai-dashboard-proxy-1 env | grep DATABASE_URL
   docker exec ai-dashboard-proxy-2 env | grep DATABASE_URL
   ```

## Performance Optimization

### Database Indexing
Ensure proper indexes on:
- client_id, ai_client, team_id
- pipeline_stage, timestamp
- model_supplier, model_name
- request_fingerprint (for correlation)

### Collector Performance
- Adjust log levels (INFO vs DEBUG)
- Configure batch size for database writes
- Tune connection pooling parameters

### Network Optimization
- Use dedicated networks for different traffic types
- Configure proper MTU for VPN traffic
- Monitor network latency between stages

## Monitoring

### Health Checks
All services include Docker health checks:
- Collectors: HTTP endpoint `/health`
- Database: `pg_isready` command
- Interval: 30s
- Timeout: 10s
- Retries: 3

### Metrics
Key metrics to monitor:
- Request throughput per stage
- Token compression ratios
- Provider selection distribution
- Error rates by stage
- End-to-end latency

### Alerts
Configure alerts for:
- Collector downtime
- Database connection failures
- High error rates
- Anomalous traffic patterns
- Cost overruns

## References

- **AI Dashboard Project**: https://github.com/levonk/ai-dashboard
- **AI Dashboard PRD**: `/Users/micro/p/gh/levonk/ai-dashboard/docs/feature/prd-multi-tenant-ai-analytics.md`
- **Headroom**: Context compression service
- **OmniRoute**: AI gateway with 177+ providers
- **Iron-Proxy**: Egress firewall and secret injection
- **NordVPN**: Privacy and geo-obfuscation