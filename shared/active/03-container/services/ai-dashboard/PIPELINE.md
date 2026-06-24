# AI Dashboard Pipeline Configuration

## Recent Changes

**2026-06-24**: Implemented Privacy Orchestrator stage in pipeline architecture
- New stage between AI Dashboard Proxy 1 and Headroom
- Implements PII detection and transformation using Rust-based Privacy Orchestrator
- **Status**: IMPLEMENTED - ai-privacy-proxy service deployed
- See "Privacy Orchestrator Implementation" section for details

## Overview

This configuration implements a multi-stage AI analytics pipeline with comprehensive data collection at key stages. The pipeline provides deep visibility into AI usage patterns, optimization effectiveness, and security analytics.

## Pipeline Architecture

```
AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
        (Entry)              (PII Detection)    (Compression)   (Routing)       (Pre-Egress)    (Security)    (Privacy)
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

2. **Privacy Orchestrator (PII Detection & Transformation)**
   - Detects and transforms PII (Personally Identifiable Information) from AI requests
   - Rust-based service with Candle ML framework integration
   - Supports 22+ PII categories across multiple languages
   - Real-time PII detection with configurable transformation modes (redaction, masking, tokenization)
   - CLI and HTTP proxy interfaces
   - **Implementation**: ai-privacy-proxy service (https://github.com/levonk/ai-privacy-proxy)
   - **Port**: 9090
   - **Upstream from**: AI Dashboard Proxy 1
   - **Downstream to**: Headroom
   - **Status**: **IMPLEMENTED** - deployed as Rust service

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

### Privacy Orchestrator Analytics
- PII detection rates and categories
- Transformation effectiveness metrics (redaction, masking, tokenization)
- Processing latency (sub-millisecond expected)
- False positive/negative rates
- Multi-language coverage statistics
- Transformation mode usage patterns

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

# Privacy Orchestrator
docker logs privacy-orchestrator --tail=50 -f

# Pre-egress stage collector
docker logs ai-dashboard-proxy-2 --tail=50 -f

# Database
docker logs ai-dashboard-db --tail=50 -f
```

### Check Health

```bash
# Entry stage health
curl http://localhost:8081/health

# Privacy Orchestrator health
curl http://localhost:9090/health

# Pre-egress stage health
curl http://localhost:8082/health

# Database health
docker exec ai-dashboard-db pg_isready -U postgres
```

### Access Analytics

- **Entry Stage API**: http://localhost:8081
- **Privacy Orchestrator API**: http://localhost:9090
- **Pre-Egress Stage API**: http://localhost:8082
- **Database**: postgresql://postgres:postgres@localhost:5432/analytics

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
- **Type**: bridge
- **Subnet**: 172.29.0.0/16
- **Gateway**: 172.29.0.1
- **Subnet**: 172.29.0.0/16
- **Purpose**: Communication with pipeline services (Headroom, OmniRoute, Iron-Proxy, NordVPN)

## Security Considerations

1. **PII Protection**: Privacy Orchestrator detects and transforms PII before data leaves the system
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

## Privacy Orchestrator Implementation

### Current Status
**IMPLEMENTED** - The Privacy Orchestrator stage is fully implemented and deployed.

### Implementation Details

The Privacy Orchestrator is a Rust-based service that provides PII detection and transformation capabilities:

**Core Functionality:**
- HTTP server/proxy that intercepts AI requests
- PII detection using Candle ML framework
- Multiple transformation modes (redaction, masking, tokenization)
- Support for 22+ PII categories across multiple languages
- CLI and HTTP proxy interfaces
- Real-time analytics and monitoring

**Technical Stack:**
- Rust with Candle ML framework
- HTTP proxy interface (port 9090)
- Docker containerization
- Health check endpoints
- Configurable PII detection thresholds
- Comprehensive logging and metrics

**Repository:**
- Project: https://github.com/levonk/ai-privacy-proxy
- Documentation: See project README and internal docs

**Architecture:**
- Rust-based service (consistent with other pipeline services)
- Candle ML framework for PII detection
- HTTP proxy interface with request/response interception
- Configurable transformation modes and thresholds
- Analytics integration with AI Dashboard
- TUI interface for monitoring and management

### Benefits of Privacy Orchestrator Service

**Architectural:**
- Separation of concerns (privacy transformation vs analytics collection)
- Reusable across different pipelines/projects
- Independent testing and validation
- Follows microservices best practices

**Operational:**
- Can scale independently based on PII processing load
- Privacy transformation updates don't affect analytics collection
- Easier to monitor and debug PII detection issues
- Can be deployed/updated independently
- TUI interface for real-time monitoring

**Performance:**
- Leverages Candle ML framework for efficient inference
- Sub-millisecond PII detection latency
- Efficient memory usage
- CPU and GPU inference options

## Troubleshooting

### Pipeline Not Starting

1. Check if all dependent services are running:
   ```bash
   docker ps | grep -E "privacy-orchestrator|headroom|omniroute|iron-proxy|nordvpn"
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
   docker logs privacy-orchestrator
   ```

### Privacy Orchestrator Issues

#### Privacy Orchestrator Not Starting

1. Check container status:
   ```bash
   docker ps | grep privacy-orchestrator
   docker logs privacy-orchestrator --tail=50
   ```

2. Verify configuration file:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml
   ```

3. Check database connectivity:
   ```bash
   docker exec privacy-orchestrator env | grep DATABASE_URL
   docker exec ai-dashboard-db pg_isready -U postgres
   ```

4. Verify network configuration:
   ```bash
   docker inspect privacy-orchestrator | grep IPAddress
   docker network inspect proxy-chain-network
   ```

#### PII Detection Not Working

1. Check detection configuration:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml | grep -A 10 "\[detection\]"
   ```

2. Test detection endpoint:
   ```bash
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com"}'
   ```

3. Check model availability:
   ```bash
   docker exec privacy-orchestrator ls -la /models/
   ```

4. Verify GPU/CPU configuration:
   ```bash
   docker exec privacy-orchestrator env | grep use_gpu
   docker exec privacy-orchestrator nvidia-smi  # if GPU enabled
   ```

#### Transformation Not Applied

1. Check transformation mode:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml | grep -A 5 "\[transformation\]"
   ```

2. Test transformation endpoint:
   ```bash
   curl -X POST http://localhost:9090/transform \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com", "mode": "redaction"}'
   ```

3. Verify upstream connection:
   ```bash
   docker exec privacy-orchestrator curl -f http://headroom:8787/health
   ```

#### High Latency Issues

1. Check resource usage:
   ```bash
   docker stats privacy-orchestrator --no-stream
   docker top privacy-orchestrator
   ```

2. Review performance metrics:
   ```bash
   curl http://localhost:9090/analytics
   ```

3. Check for bottlenecks:
   ```bash
   docker logs privacy-orchestrator | grep "latency"
   ```

4. Optimize configuration:
   - Reduce detection categories if not all needed
   - Enable GPU if available
   - Increase worker threads
   - Enable caching

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