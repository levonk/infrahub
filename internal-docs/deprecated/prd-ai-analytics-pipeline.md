---
# Product Requirements Document (PRD)

## ⚠️ DEPRECATED - Replaced by AI Dashboard

**This PRD has been deprecated and replaced by the [ai-dashboard](https://github.com/levonk/ai-dashboard) project.**

### Replacement Details

- **Completion Status**: This project was 24% complete (8/33 stories done)
- **Replacement**: ai-dashboard is 88% complete (15/17 stories done) and production-ready
- **Architecture**: ai-dashboard provides a simpler 2-service architecture (proxy + web) vs the complex 4-service architecture planned here
- **Technology**: ai-dashboard uses Rust for high-performance analytics vs Python collectors
- **Integration**: ai-dashboard is now integrated as external containers in infrahub at `/Users/micro/p/gh/levonk/infrahub/shared/active/03-container/services/ai-dashboard/`

### Migration Path

1. The incomplete Python-based collectors have been removed from infrahub
2. ai-dashboard proxy and database services are now available as external containers
3. All future analytics development should use the ai-dashboard project
4. This PRD is preserved for historical reference only

---

## Introduction / Overview
- **Feature name:** AI Analytics Pipeline (Open Source Edition) - DEPRECATED
- **Summary:** A comprehensive single-tenant analytics pipeline for AI requests that provides full visibility into query patterns, compression effectiveness, routing decisions, security metrics, and usage patterns across multiple AI proxy layers (Headroom, OmniRoute, Iron-Proxy). Features advanced analytics including subagent attribution, tool-level tracking, file-level analytics, session analysis, and rule-based optimization recommendations. Architecture designed to be extensible for future multi-tenant enterprise capabilities.
- **Context:**
  - This feature is for developers and power users using multiple AI coding agents and proxy services who need deep visibility into their AI usage patterns, costs, and security posture.
  - Addresses the lack of comprehensive observability across the AI toolchain, particularly when using multiple optimization and routing layers.
  - Extends token-dashboard capabilities with real-time pipeline monitoring, user-level analytics, advanced time granularity, and configuration management.
  - Architecture supports future enterprise licensing with multi-tenant capabilities (business planning separate).
  - Single-tenant deployment focused on personal/small-team use cases with SQLite storage.

## Goals
- Provide comprehensive observability across the entire AI request pipeline from client to provider
- Enable comparative analysis between pre- and post-transformation requests (compression, routing, security)
- Support personal and small-team deployment with SQLite storage and simple setup
- Deliver actionable insights for cost optimization, security monitoring, and performance improvement
- Maintain zero latency impact on AI requests through asynchronous processing architecture
- Design extensible architecture that can support future enterprise multi-tenant capabilities

## User Stories
- As a developer using multiple AI coding agents, I want to see how much each compression layer saves in tokens so I can optimize my prompts and tool configurations.
- As a security-conscious user, I want to monitor what requests are being allowed/blocked by iron-proxy so I can ensure my security policies are effective.
- As a cost-conscious user, I want to understand which AI providers my requests are routed to and their actual costs so I can optimize my provider selection.
- As a DevOps engineer, I want to deploy this pipeline in my home network for personal use with simple Docker setup.
- As a developer, I want to compare original vs compressed queries to understand if compression is affecting AI response quality.
- As a power user, I want to set up alerts for anomalous AI usage patterns that might indicate security issues or cost problems.
- As a developer, I want to see which subagents (Claude Code, Codex, Pi, Devin) are making requests and their associated costs.
- As a cost-conscious user, I want to identify wasteful patterns like repeated file reads and oversized tool results.
- As a developer, I want to analyze my sessions turn-by-turn to understand conversation patterns and costs.
- As a developer, I want to see file-level analytics to understand which files are accessed most and their token costs.
- As a developer, I want to manage API provider configurations through a visual interface.
- As a developer, I want to receive actionable tips for reducing token usage based on rule-based analysis.
- As a developer, I want to view analytics with flexible time granularity (minute to all-time) and period-over-period comparisons.

## Functional Requirements

### Core Pipeline Architecture
- Implement two analytics collectors in the request pipeline:
  - Collector 1: Placed before Headroom to capture original, untransformed requests
  - Collector 2: Placed after OmniRoute and before Iron-Proxy to capture compressed and routed requests
- Collectors must be lightweight with minimal latency impact (<5ms per request)
- Implement asynchronous processing pipeline using message queue (Redis) and background processor
- Support hot path (request forwarding) and async path (analytics processing) separation

### Data Collection
- Capture request metadata: timestamp, client ID, request size, content hash, estimated token count
- Capture response metadata: response size, response time, status code, provider used
- Capture pipeline stage information: pre-processing vs post-processing markers
- Support routing metadata from OmniRoute (selected provider, routing decisions)
- Capture compression metadata from Headroom (algorithm used, compression ratio)
- **User-Level Attribution**: User, Machine, Client Key for request tracking
- **Downstream Tracking**: Provider, Model, Model Version with historical changes
- **Subagent Attribution**: Track which AI agents (Claude Code, Codex, Pi, Devin, etc.) made specific requests
- **Tool-Level Analytics**: Tool usage patterns, tool result sizes, tool invocation frequency
- **File-Level Analytics**: File access patterns, file touch frequency, file-level token usage

### Analytics Processing
- Implement content hashing for request correlation between pipeline stages
- Calculate compression ratios by comparing pre- and post-processing request sizes
- Aggregate metrics by time period, client, provider, and content type
- Support comparative analysis between pipeline stages
- Calculate pipeline latency breakdown by component
- **User-Level Aggregation**: Support aggregation by user, machine, client key
- **Time Granularity Support**: Minute, Hour, Day, Week, Month, Quarter, Year, All-time
- **Period-over-Period Analysis**: Both absolute numbers and changes (delta) between time periods
- **Cache Performance Analytics**: Detailed cache hit/miss ratios, cache savings calculations
- **Cost Calculation**: Per-prompt cost breakdown, tool-level cost attribution, subagent cost tracking

### Dashboard and Visualization
- Provide web-based dashboard for analytics visualization
- Show compression effectiveness over time with charts
- Display provider performance metrics (latency, success rates, costs)
- Present pipeline performance breakdown (time spent in each component)
- Enable query inspection to view original vs compressed requests
- Support security dashboard showing iron-proxy allow/block decisions
- **Advanced Analytics Tabs**:
  - **Overview**: KPIs, request volume, cost trends, system health status
  - **Compression Analytics**: Compression effectiveness, token savings, query comparison tool
  - **Provider Analytics**: Provider performance, routing decisions, provider comparison
  - **Pipeline Performance**: Latency breakdown, throughput analysis, component health
  - **Security Analytics**: Iron-proxy decisions, audit log viewer
  - **Query Inspector**: Advanced search, request detail view, request lifecycle timeline
  - **Cost Analysis**: Cost breakdown, optimization insights, cost forecasting
  - **Session Analytics**: Turn-by-turn session analysis, session-by-session tracking, recent sessions timeline
  - **Skills & Tools**: Skills invocation analytics, top tools by call count, tool result size analysis
  - **File Analytics**: File touch frequency, file-level token usage, project file heatmaps
  - **Alerts & Notifications**: Active alerts, alert configuration, alert history
  - **Settings & Configuration**: Data retention, integration settings, system configuration
- **Visual Configuration Management**: Visual YAML/JSON editor with syntax highlighting and diff preview
- **Provider Management UI**: Manage API providers, credentials, model aliases
- **Real-time Log Viewing**: Live log tailing with search, filtering, and error log downloads
- **Rule-Based Tips Engine**: Suggestions for cost optimization, wasteful pattern detection

### Security and Compliance
- Ensure analytics collectors have no access to API keys (only iron-proxy has keys)
- Support data retention policies and configurable data pruning
- Implement secure storage for analytics data (SQLite with optional encryption)
- Support audit logging for analytics system itself

### Deployment and Operations
- Support Docker containerization for all components
- Provide configuration via environment variables and YAML files
- Include health checks and monitoring endpoints
- Support graceful degradation if analytics components are unavailable
- Implement backup and recovery for analytics data

### Licensing and Architecture
- Design architecture to be extensible for future enterprise capabilities
- Use AGPL 3.0 license for open-source distribution
- Support simple configuration via environment variables and YAML files
- Enable scalability for personal/small-team deployments
- **User-Level Analytics**:
  - User, machine, and client key attribution for request tracking
  - User-specific dashboards and views
  - Data segregation by user for basic privacy
- **Advanced Filtering & Search**:
  - Multi-dimensional filtering by user, providers, models, time ranges
  - Saved searches and filter combinations for quick access
  - Advanced query builder for complex searches
  - Export functionality for filtered results
- **Configuration Management**:
  - Visual YAML/JSON configuration editor with syntax highlighting
  - Configuration diff preview before saving changes
  - Provider configuration UI (API keys, headers, proxies, model aliases)
  - Model management (availability, version tracking)
- **Authentication & Credentials**:
  - Basic auth for dashboard access
  - Local credential management for API providers
  - Credential runtime indicators

## Non-Functional Requirements

### Performance
- Hot path latency: <5ms additional latency per request from collectors
- Async processing: Analytics processing must not block AI requests
- Throughput: Support 1000+ requests/second for enterprise edition
- Dashboard response time: <2 seconds for standard analytics queries

### Security
- Zero API key exposure: Only iron-proxy may access real API credentials
- Data encryption: Support encryption at rest for sensitive analytics data
- Network security: All inter-service communication over internal networks
- Authentication: Dashboard access with configurable authentication (basic auth for personal, SSO for enterprise)

### Reliability
- Availability: 99.5% uptime for analytics pipeline (non-blocking for AI requests)
- Data durability: No data loss if message queue is temporarily unavailable
- Graceful degradation: AI pipeline continues if analytics components fail
- Recovery: Automatic recovery from transient failures

### Scalability
- Horizontal scaling: Support multiple collector instances behind load balancer
- Storage scaling: Support migration from SQLite to PostgreSQL for enterprise
- Queue scaling: Support Redis Cluster for high-volume deployments
- Multi-region: Support distributed deployment for enterprise customers

### Maintainability
- Logging: Comprehensive logging for all components with configurable log levels
- Monitoring: Health check endpoints and metrics export (Prometheus format)
- Documentation: Complete setup and configuration documentation
- Testing: Unit tests for core logic, integration tests for pipeline

## Technical Considerations

### Architecture Components
- **Analytics Collectors**: Lightweight HTTP proxies written in Python (stdlib only for reliability)
- **Message Queue**: Redis for reliable message buffering between collectors and processor
- **Analytics Processor**: Background service consuming from queue, processing and storing analytics
- **Storage**: SQLite for personal edition, PostgreSQL for enterprise edition
- **Dashboard**: Web UI using vanilla JavaScript and ECharts (no build step, like token-dashboard)

### Integration Points
- **Headroom Integration**: Capture compression metadata via response headers or side-channel
- **OmniRoute Integration**: Parse routing metadata from response headers
- **Iron-Proxy Integration**: Consume iron-proxy audit logs for security analytics
- **Client Integration**: Support standard HTTP proxy configuration (HTTP_PROXY/HTTPS_PROXY)

### Data Model
- **Request events**: timestamp, stage, content_hash, request_size, client_id, metadata
- **User attribution**: user_id, machine_id, client_key_id
- **Response events**: timestamp, content_hash, response_size, response_time, status_code, provider
- **Downstream tracking**: provider_id, model_id, model_version, historical tracking
- **Subagent attribution**: subagent_type (Claude Code, Codex, Pi, Devin, etc.), subagent_instance_id
- **Tool-level data**: tool_name, tool_invocation_count, tool_result_size, tool_cost
- **File-level data**: file_path, file_touch_count, file_token_usage, file_heatmap_data
- **Cache analytics**: cache_hit_count, cache_miss_count, cache_savings, cache_hit_rate
- **Session data**: session_id, turn_count, session_tokens, session_cost, session_timeline
- **Skills data**: skill_name, skill_invocation_count, skill_cost, skill_effectiveness
- **Derived metrics**: compression_ratio, pipeline_latency, cost_estimates, period_over_period_changes
- **Aggregated data**: time-series aggregates by user, providers, models, time granularities
- **Configuration data**: provider_configs, model_aliases, auth_files

### Technology Constraints
- Python 3.8+ for collectors and processor (stdlib preferred for reliability)
- SQLite for storage (single-tenant, simple deployment)
- Redis for message queuing
- Vanilla JavaScript for dashboard (no framework dependencies)
- Docker for containerization
- AGPL 3.0 license for open-source distribution

## Success Metrics
- **Adoption**: Successfully deployed in personal environment with 3+ AI clients connected
- **Performance**: Hot path latency consistently <5ms per request
- **Reliability**: 99.5% uptime for analytics pipeline without impacting AI requests
- **Insights**: Demonstrate measurable cost savings through compression analytics (>15% savings identified)
- **Enterprise Readiness**: Complete licensing mechanism and enterprise feature flags implemented
- **User Satisfaction**: Dashboard provides actionable insights leading to configuration changes

## Open Questions
- Should the analytics processor support real-time streaming analytics or batch processing only?
- What specific enterprise features should be included in the licensed version (SSO, RBAC, advanced analytics)?
- Should the system support multi-tenant data isolation for enterprise deployments?
- What is the target pricing model for the enterprise license?
- Should the dashboard support alert configuration and notification delivery?

## Dependencies
- **Existing Projects**: Integration with Headroom, OmniRoute, and Iron-Proxy configurations
- **Infrastructure**: Docker and Docker Compose for deployment
- **Message Queue**: Redis instance for message buffering
- **Storage**: SQLite (personal) or PostgreSQL (enterprise) for analytics data
- **Monitoring**: Optional Prometheus integration for metrics export

## Timeline / Milestones

### Phase 1: Foundation & Core Pipeline (Weeks 1-3)
- Implement basic analytics collectors (pre and post processing)
- Set up Redis message queue and basic processor
- Implement SQLite storage with user-level data model
- Create minimal dashboard with request volume metrics
- Implement basic time granularity support (hour/day/week)

### Phase 2: Advanced Analytics (Weeks 4-6)
- Implement compression ratio calculations and cache analytics
- Add provider performance analytics with model tracking
- Create comparative analysis between pipeline stages
- Implement subagent attribution and tool-level analytics
- Add file-level analytics and session tracking
- Enhance dashboard with advanced charts and visualizations

### Phase 3: Security & Integration (Weeks 7-9)
- Integrate with iron-proxy audit logs
- Add security dashboard and allow/block analytics
- Implement query inspection feature with advanced filtering
- Add data retention and pruning capabilities
- Implement real-time log viewing and log management

### Phase 4: Configuration & Management (Weeks 10-12)
- Add visual configuration management (YAML/JSON editor)
- Implement provider management UI and credential management
- Add model management (aliases, version tracking)
- Implement basic authentication for dashboard access

### Phase 5: Advanced Features & Optimization (Weeks 13-15)
- Implement rule-based tips engine for cost optimization
- Add wasteful pattern detection and recommendations
- Implement advanced time granularity (minute/quarter/year/all-time)
- Add period-over-period analysis
- Implement alerting system for anomalous patterns

### Phase 6: Testing and Documentation (Weeks 16-18)
- Comprehensive testing across all components
- Performance testing and optimization
- Complete documentation and setup guides
- Create deployment materials and Docker configurations
- User acceptance testing and feedback integration

---
*Generated from PRD template*