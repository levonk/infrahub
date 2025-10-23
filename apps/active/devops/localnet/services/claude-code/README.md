# Claude Code Integration for Job-Aide Monorepo

This directory contains the complete Claude Code integration for the job-aide monorepo, providing a containerized Claude Code environment with MCP (Model Context Protocol) tool integration, authentication, and web UI access.

## Overview

The Claude Code Integration enables secure, containerized access to Claude Code with enhanced functionality through MCP tools. It provides a complete development environment that integrates seamlessly with the broader localnet infrastructure.

## Architecture

The integration consists of multiple Docker containers working together:

### Core Services

#### `claude-code`
**Purpose**: Main Claude Code service with cc-tools integration
**Image**: Custom built from `docker/Dockerfile`
**Key Dependencies**:
- `cc-tools` - GitHub repository providing Claude Code tooling
- Python 3 with pip packages
- Git for repository operations
- Bash for scripting

**Configuration**:
- Environment: `CLAUDE_API_KEY`, `CLAUDE_CODE_CONFIG_DIR`, `CLAUDE_CODE_DATA_DIR`
- Ports: Internal 8081 (not exposed externally)
- Volumes: `claude-code-config`, `claude-code-data`

#### `claude-code-ui`
**Purpose**: Web-based UI for accessing Claude Code
**Image**: `siteboon/claudecodeui:latest`
**Key Features**:
- Modern web interface for Claude Code interactions
- Integration with authentication service
- Responsive design for development workflows

**Configuration**:
- Environment: `CLAUDE_CODE_API_URL`, `CLAUDE_CODE_AUTH_URL`
- Ports: External 3000 → Internal 3000
- Dependencies: `claude-code`, `claude-code-auth`

### Authentication & Security

#### `claude-code-auth`
**Purpose**: Authentication service managing API keys and sessions
**Image**: Custom built from `docker/Dockerfile.auth`
**Key Features**:
- JWT-based authentication
- API key management and validation
- Session handling with configurable expiration

**Configuration**:
- Environment: `JWT_SECRET`, `API_KEYS_FILE`
- Ports: External 8080 → Internal 8080
- Volumes: `claude-code-config` (for API keys storage)

### MCP (Model Context Protocol) Integration

#### `claude-code-mcp`
**Purpose**: MCP server providing tool integration capabilities
**Image**: `steipete/claude-code-mcp:latest`
**Key Features**:
- Tool discovery and registration
- MCP protocol implementation
- Secure tool execution environment

**Configuration**:
- Environment: `MCP_CONFIG_FILE`
- Volumes: `claude-code-config`, Docker socket (REMOVED for security)
- Dependencies: `claude-code`
- Security: Runs without Docker socket access for enhanced security

#### `pluggedin-mcp-proxy`
**Purpose**: MCP proxy service for secure tool communication
**Image**: `veritexnik/pluggedin-mcp-proxy:latest`
**Key Features**:
- Proxy between MCP clients and servers
- Request routing and load balancing
- Authentication and authorization

**Configuration**:
- Environment: `MCP_TARGET_URL`, `PROXY_CONFIG_FILE`
- Ports: Internal 8085 (not exposed externally)
- Volumes: `claude-code-config`
- Dependencies: `claude-code-mcp`

#### `pluggedin-app`
**Purpose**: Enhanced Claude Code application with additional features
**Image**: `veritexnik/pluggedin-app:latest`
**Key Features**:
- Extended Claude Code functionality
- Integration with MCP tools
- Advanced development workflows

**Configuration**:
- Environment: `CLAUDE_CODE_URL`, `MCP_PROXY_URL`
- Ports: Internal 8086 (not exposed externally)
- Dependencies: `claude-code`, `pluggedin-mcp-proxy`

### Data Persistence

#### `claude-code-db`
**Purpose**: PostgreSQL database for session and conversation storage
**Image**: `postgres:15-alpine`
**Key Features**:
- Session persistence
- Conversation history
- User data storage

**Configuration**:
- Environment: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- Volumes: `claude-code-db` (persistent data)
- Security: Isolated network, strong password requirements

## Key Dependencies and Packages

### External Packages and Images

- **`cc-tools`** (`https://github.com/Veraticus/cc-tools`)
  - Core tooling for Claude Code integration
  - Provides command-line interface and utilities
  - Includes Python dependencies and shell scripts

- **`claude-code-mcp`** (`https://github.com/steipete/claude-code-mcp`)
  - MCP server implementation
  - Tool discovery and execution framework
  - Protocol-compliant MCP implementation

- **`claudecodeui`** (`https://github.com/siteboon/claudecodeui`)
  - Modern web UI for Claude Code
  - Responsive interface design
  - Authentication integration

- **`pluggedin-mcp-proxy`** (`https://github.com/VeriTeknik/pluggedin-mcp-proxy`)
  - MCP proxy for secure communication
  - Load balancing and routing
  - Request filtering and security

- **`pluggedin-app`** (`https://github.com/VeriTeknik/pluggedin-app`)
  - Enhanced Claude Code application
  - Additional features and integrations
  - Extended workflow support

### Container Base Images

- **`alpine:3.19`** - Minimal Linux distribution for custom services
- **`postgres:15-alpine`** - PostgreSQL database with Alpine Linux
- **External images** - Pre-built services from verified sources

## Configuration Files

### MCP Configuration
- `cc-tools-config/mcp-config.json` - MCP server configuration
- `cc-tools-config/proxy-config.json` - MCP proxy configuration

### Environment Variables
See `env.example` for complete list of required environment variables:

- `CLAUDE_API_KEY` - Anthropic Claude API key
- `CLAUDE_CODE_JWT_SECRET` - JWT signing secret
- `CLAUDE_CODE_DB_PASSWORD` - Database password
- Additional optional variables for customization

## Network Architecture

All services run on an isolated Docker network (`claude-code-network`) with:
- Internal communication only (no external access to APIs)
- DNS-based service discovery
- Secure inter-service communication
- Firewall rules preventing unauthorized access

## Security Features

- **Non-root execution** in all custom containers
- **Isolated network** preventing external access
- **No Docker socket mounting** (removed for security)
- **Environment-based secrets** management
- **JWT authentication** for API access
- **Encrypted database connections**

## Setup and Usage

### Prerequisites
- Docker and Docker Compose
- Valid Claude API key
- Localnet infrastructure running

### Quick Start

```bash
# Build all services
make build

# Start services
make up

# Check health
make health-check

# Access web UI at http://localhost:3000
```

### Development Workflow

```bash
# View logs
make logs

# Access container shell
make shell

# Restart services
make restart

# Stop and cleanup
make down
make clean
```

## Build System

The Makefile provides convenient commands for managing the entire stack:

- `build` - Build all Docker images
- `up` - Start all services
- `down` - Stop all services
- `restart` - Restart services
- `logs` - View service logs
- `health-check` - Verify service health
- `status` - Show container status
- `shell` - Access main container
- `clean` - Remove containers (keep data)
- `clean-all` - Remove everything (WARNING: destroys data)

## API Endpoints and Authentication

### Authentication

The Claude Code integration uses API key-based authentication with JWT tokens for session management:

1. **API Key Authentication**: Clients provide an API key in the `Authorization: Bearer {api-key}` header
2. **Session Management**: Valid API keys create authenticated sessions with configurable expiration (24 hours)
3. **Rate Limiting**: 100 requests/minute, 1000 requests/hour per authenticated session

### Web UI API

The web interface exposes the following REST endpoints (see `../../../contracts/web-ui-api.yaml` for complete OpenAPI specification):

#### `POST /sessions`

Creates a new Claude Code session for authenticated users.

**Request Body**:
```json
{
  "user_id": "string",
  "preferences": {
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 4096
  }
}
```

**Response** (201 Created):
```json
{
  "session_id": "uuid",
  "created_at": "2025-10-23T10:00:00Z",
  "expires_at": "2025-10-24T10:00:00Z",
  "web_ui_url": "https://claude-code.localnet/session/uuid"
}
```

**Authentication**: Required (API key in Authorization header)

#### Error Responses

All endpoints return standardized error responses:
```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "retry_after": 60
}
```

### MCP Tool Integration

The MCP (Model Context Protocol) provides tool integration capabilities:

- **Tool Discovery**: Automatic discovery and registration of available MCP tools
- **Secure Execution**: Tools run in isolated containers with proper security boundaries
- **Protocol Compliance**: Full MCP v1.0 protocol implementation for tool communication

### Database Schema

Session and conversation data follows the schema defined in `../../../specs/002-claude-code-integration/data-model.md`:

- **UserSession**: API key validation and session management
- **Conversation**: Message history and metadata storage
- **Message**: Individual chat messages with token counting
- **MCPTool**: Registered tools and capabilities
- **ToolUsage**: Tool execution tracking and performance metrics

## Troubleshooting

### Common Issues

1. **Services won't start**
   - Ensure localnet infrastructure is running
   - Check environment variables in `.env` file
   - Verify Docker resources (CPU/memory)

2. **Authentication failures**
   - Validate `CLAUDE_API_KEY`
   - Check JWT secret configuration
   - Verify API key file permissions

3. **MCP tool issues**
   - Check MCP server logs: `make logs`
   - Verify configuration files in `cc-tools-config/`
   - Ensure network connectivity between services

4. **Database connection errors**
   - Check `CLAUDE_CODE_DB_PASSWORD`
   - Verify database volume permissions
   - Check PostgreSQL logs

### Debugging Commands

```bash
# View detailed logs
make logs-follow

# Check service status
make status

# Access container directly
make shell

# Health verification
make health-check
```

## Production Deployment

### Prerequisites for Production Deployment

- **Infrastructure Requirements**:
  - Docker Engine 24.0+ with Compose V2
  - PostgreSQL 15+ database server (external or containerized)
  - SSL/TLS certificates for HTTPS endpoints
  - DNS configuration for production domains
  - Network security groups/firewalls configured

- **Security Requirements**:
  - Valid Claude API key with production access
  - Strong JWT secret (64 bytes, cryptographically secure)
  - Secure database credentials (32+ characters)
  - SSL/TLS certificates from trusted CA
  - Network isolation (internal Docker networks only)

### Production Environment Setup

1. **Clone the production environment template**:
   ```bash
   cp env.production .env.production
   # Edit .env.production with production values
   ```

2. **Configure SSL/TLS certificates**:
   - Place certificates in `ssl/` directory
   - Update nginx configuration for SSL termination
   - Enable HSTS headers

3. **Set up external PostgreSQL** (recommended for production):
   ```bash
   # Create production database
   createdb -U postgres claude_code_prod
   psql -U postgres -d claude_code_prod -f sql/schema.sql
   ```

### Production Deployment Checklist

#### Pre-Deployment
- [ ] All integration tests passing (`make test-integration`)
- [ ] Security scan completed (no critical vulnerabilities)
- [ ] Performance testing completed (95% requests <5 seconds)
- [ ] Production environment variables configured
- [ ] SSL/TLS certificates installed and valid
- [ ] DNS records configured for production domains
- [ ] Database backup created
- [ ] Rollback plan documented and tested

#### Security Hardening
- [ ] Non-root container execution verified
- [ ] Network isolation confirmed (internal networks only)
- [ ] Resource limits applied (2GB RAM, 2 CPU cores max)
- [ ] Secrets stored in secure vault (not in environment files)
- [ ] API key rotation procedure documented
- [ ] Audit logging enabled
- [ ] HTTPS enforcement configured
- [ ] CSP headers enabled

#### Deployment Steps
- [ ] Build production images: `make build`
- [ ] Run pre-deployment health checks: `make health-check`
- [ ] Deploy to staging environment first
- [ ] Validate staging deployment (24-48 hours)
- [ ] Deploy to production environment
- [ ] Run post-deployment tests
- [ ] Enable production monitoring and alerting

#### Post-Deployment
- [ ] Monitoring dashboards configured
- [ ] Alerting rules active
- [ ] Backup procedures scheduled
- [ ] Log aggregation working
- [ ] Performance monitoring active
- [ ] Security monitoring enabled

### Monitoring and Observability

#### Health Checks
- **Container Health**: All services report healthy status
- **API Endpoints**: Authentication and session creation functional
- **Database**: Connection pool healthy, no connection errors
- **MCP Integration**: Tool discovery and execution working

#### Metrics to Monitor
- **Performance**: API response times (<5 seconds 95% of requests)
- **Resource Usage**: CPU <80%, Memory <80%
- **Error Rates**: Authentication failures <5%, API errors <1%
- **Security**: Failed authentication attempts, suspicious patterns

#### Logging Configuration
```yaml
# docker-compose.production.yml logging configuration
services:
  claude-code:
    logging:
      driver: json-file
      options:
        max-size: 10m
        max-file: "3"
        labels: service,environment
```

### Rollback Procedures

#### Automated Rollback (Preferred)
```bash
# Quick rollback to previous version
make rollback

# Or manually:
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml pull  # Pull previous images
docker-compose -f docker-compose.production.yml up -d
```

#### Manual Rollback Steps
1. **Stop current deployment**:
   ```bash
   docker-compose -f docker-compose.production.yml down
   ```

2. **Restore from backup** (if database changes made):
   ```bash
   pg_restore -U claude_prod_user -d claude_code_prod backup.sql
   ```

3. **Deploy previous version**:
   ```bash
   # Tag previous images as latest, or use specific tags
   docker-compose -f docker-compose.production.yml up -d
   ```

4. **Verify rollback success**:
   ```bash
   make health-check
   # Check application functionality
   curl -f https://claude-code.yourdomain.com/health
   ```

#### Rollback Triggers
- **Automatic**: Health checks fail for >5 minutes
- **Manual**: Error rate >10%, Performance degradation >50%
- **Emergency**: Security incident detected

### Backup and Recovery

#### Database Backups
```bash
# Daily backup script
#!/bin/bash
BACKUP_DIR="/backups/claude-code"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

pg_dump -U claude_prod_user -h db-host claude_code_prod \
  | gzip > ${BACKUP_DIR}/claude_code_prod_${TIMESTAMP}.sql.gz

# Keep last 30 days
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +30 -delete
```

#### Configuration Backups
- Environment files encrypted and versioned
- Docker Compose files version controlled
- SSL certificates with renewal automation

### Incident Response

#### Security Incident Procedure
1. **Isolate**: Disconnect affected services from network
2. **Assess**: Review logs for breach indicators
3. **Contain**: Rotate all API keys and secrets
4. **Recover**: Deploy from clean backup
5. **Report**: Document incident and remediation

#### Performance Incident Procedure
1. **Monitor**: Identify bottleneck (CPU, memory, database)
2. **Scale**: Increase resources or scale horizontally
3. **Optimize**: Review and fix performance issues
4. **Rollback**: If optimization fails, rollback deployment

## Database Fallback Options

### Overview

The Claude Code Integration Service supports multiple database backends through a unified abstraction layer:

- **PostgreSQL** (Default): Full-featured OLTP database with concurrent access, ACID compliance, and advanced features
- **SQLite** (Fallback): Lightweight, file-based database perfect for single-user scenarios or development

### When to Use PostgreSQL
- Multiple concurrent users/sessions
- High-availability requirements
- Advanced features needed (complex queries, triggers, stored procedures)
- Production deployments with multiple agents/worktrees
- Data integrity and concurrent access critical

### When to Use SQLite
- Single-user development/local testing
- Lightweight deployments
- Resource-constrained environments
- Simple data persistence without concurrency needs
- Prototyping and experimentation

### Configuration

#### Environment Variables

```bash
# Database Type Selection
DATABASE_TYPE=postgresql  # or 'sqlite'

# PostgreSQL Settings (when DATABASE_TYPE=postgresql)
DATABASE_URL=postgresql://user:password@host:port/database
CLAUDE_CODE_DB_PASSWORD=your_secure_password

# SQLite Settings (when DATABASE_TYPE=sqlite)
SQLITE_PATH=/app/data/claude_code.db
```

#### Docker Compose Usage

```bash
# PostgreSQL (default - concurrent access)
docker compose up

# SQLite (lightweight - single-user)
DATABASE_TYPE=sqlite docker compose up

# PostgreSQL with explicit profile (same as default)
docker compose --profile postgresql up
```

### Database Schema Compatibility

The abstraction layer ensures both databases use compatible schemas:

- **UUID Primary Keys**: Both support UUID generation
- **JSON Storage**: PostgreSQL uses JSONB, SQLite stores as TEXT
- **Timestamps**: Both support ISO format timestamps
- **Constraints**: Foreign keys and check constraints work in both
- **Indexing**: Optimized indexes for both query patterns

### Migration Between Databases

Data can be migrated between PostgreSQL and SQLite using standard export/import tools:

```bash
# Export from PostgreSQL
pg_dump -h localhost -U user -d claude_code > export.sql

# Import to SQLite (with schema conversion)
# Note: Some advanced PostgreSQL features may need manual adaptation
```

### Performance Characteristics

#### PostgreSQL
- **Concurrent Connections**: 100+ simultaneous users
- **Query Performance**: Excellent for complex queries
- **Storage**: Efficient for large datasets
- **Backup/Restore**: Built-in tools available

#### SQLite
- **Concurrent Connections**: Single-writer, multiple readers
- **Query Performance**: Fast for simple queries
- **Storage**: Single file, easy backup
- **Resource Usage**: Minimal CPU/memory footprint

### Security Considerations

#### PostgreSQL
- Network isolation required
- User authentication and permissions
- SSL/TLS encryption for connections
- Regular security updates needed

#### SQLite
- File system security critical
- No network access (file-based)
- Container volume permissions important
- Backup file protection essential

### Development Setup

#### Quick SQLite Development
```bash
# Use SQLite for fast development cycles
export DATABASE_TYPE=sqlite
export SQLITE_PATH=./dev.db

# Start services
docker compose up

# Database persists in local file
ls -la dev.db
```

#### PostgreSQL Production
```bash
# Use PostgreSQL for production features
export DATABASE_TYPE=postgresql
export DATABASE_URL=postgresql://prod_user:secure_pass@db.host:5432/claude_prod

# Start with PostgreSQL profile
docker compose --profile postgresql up
```

### Testing Both Backends

```bash
# Test with PostgreSQL
DATABASE_TYPE=postgresql make test-integration

# Test with SQLite
DATABASE_TYPE=sqlite make test-integration
```

### Monitoring and Maintenance

#### PostgreSQL
- Connection pooling monitoring
- Query performance analysis
- Regular VACUUM operations
- Backup verification

#### SQLite
- File size monitoring
- WAL file management (if enabled)
- Regular VACUUM operations
- Backup file integrity checks
