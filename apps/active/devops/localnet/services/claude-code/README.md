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

## Integration with Job-Aide Monorepo

This service integrates with the broader job-aide ecosystem:

- **Localnet Infrastructure**: Uses DNS and networking from localnet
- **Environment Variables**: Shared configuration with other services
- **Data Persistence**: Isolated volumes for service data
- **Monitoring**: Health checks and logging integration

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

## Related Documentation

- `../../../specs/002-claude-code-integration/tasks.md` - Implementation tasks
- `../../../specs/002-claude-code-integration/spec.md` - Complete specifications
- `../../../specs/002-claude-code-integration/data-model.md` - Data structures
- `../../../contracts/web-ui-api.yaml` - API specifications
