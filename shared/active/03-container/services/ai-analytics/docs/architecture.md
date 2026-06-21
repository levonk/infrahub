# AI Analytics Pipeline - Architecture

## Overview

The AI Analytics Pipeline is a comprehensive system for tracking AI usage across multiple dimensions. It implements a dual-architecture approach:

- **Open-source version**: 2-service architecture (proxy + web) for single-tenant deployments
- **Commercial version**: 4-service architecture (proxy + collector + analytics + web) for multi-tenant scale

## System Components

### 1. Collectors

Data collectors that gather analytics from various sources:

- **HTTP Proxy Collector**: Intercepts and logs HTTP requests to AI providers
- **Client SDK Collector**: Receives telemetry from client applications
- **Webhook Collector**: Processes webhook events from external systems

### 2. Message Queue

Asynchronous message processing queue:

- **Development**: Redis for simplicity
- **Production**: RabbitMQ for reliability and scaling

### 3. Processor

Background processing engine that:

- Consumes events from the queue
- Performs data validation and normalization
- Computes aggregations across multiple dimensions
- Writes processed data to the database

### 4. Database

Storage layer for analytics data:

- **Single-tenant**: SQLite for simplicity
- **Multi-tenant**: PostgreSQL for scalability and concurrent access

### 5. API

REST API for data access:

- Query endpoints for analytics data
- Aggregation endpoints for computed metrics
- Admin endpoints for configuration management

### 6. Dashboard

Web interface for visualization:

- Overview and KPIs
- Provider analytics
- Pipeline performance
- Security analytics
- Cost analysis

## Data Flow

```
AI Client → Collector → Queue → Processor → Database → API → Dashboard
```

## Multi-Dimensional Analytics

The system tracks analytics across these dimensions:

- **Client**: Company or organization using the AI services
- **AI Client**: Specific AI client (Claude Code, Codex, Pi, Devin, etc.)
- **Team**: Team or department within the client organization
- **Pipeline Stage**: Stage in the AI processing pipeline
- **Provider**: AI model provider (Anthropic, OpenAI, Google, etc.)
- **Model**: Specific AI model being used
- **Input Type**: Type of input (text/chat, image, audio, etc.)

## Scalability Considerations

### Horizontal Scaling

- Collector services can be scaled horizontally
- Processor workers can be increased based on queue size
- API services can be load-balanced

### Vertical Scaling

- Database can be upgraded to larger instances
- Queue can be clustered for high availability
- Caching layer can be added for frequently accessed data

## Security

- All data encrypted at rest
- TLS for all network communications
- API authentication and authorization
- Audit logging for all operations
- Data retention policies

## Monitoring

- Health checks for all services
- Metrics collection (Prometheus-compatible)
- Log aggregation and analysis
- Alerting for critical issues
