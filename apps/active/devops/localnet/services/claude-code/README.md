# Claude Code Integration - Build System

This directory contains the specifications and build system for integrating Claude Code with the job-aide monorepo.

## Quick Start

From this directory (`specs/002-claude-code-integration/`), you can use the provided Makefile to easily manage Claude Code Docker containers:

```bash
# Build the Docker images
make build

# Start all Claude Code services
make up

# Check service health
make health-check

# View logs
make logs

# Stop services
make down

# Clean up containers (keeps data volumes)
make clean

# Full cleanup including data volumes (WARNING: destroys data!)
make clean-all
```

## Available Commands

Run `make help` to see all available commands:

- `build` - Build Docker images for all Claude Code services
- `up` - Start all services in detached mode
- `down` - Stop all services
- `restart` - Restart all services
- `logs` - View recent logs from all services
- `logs-follow` - Follow logs in real-time
- `health-check` - Run health checks on all services
- `status` - Show status of all containers
- `shell` - Open shell in the main Claude Code container
- `clean` - Remove containers and networks (preserves data volumes)
- `clean-all` - Remove everything including data volumes (with confirmation)

## Architecture

The Claude Code integration consists of multiple Docker services:

- **claude-code**: Main Claude Code service with cc-tools integration
- **claude-code-ui**: Web UI for Claude Code access
- **claude-code-auth**: Authentication service with API key management
- **claude-code-mcp**: MCP server for tool integration
- **pluggedin-mcp-proxy**: MCP proxy service
- **pluggedin-app**: Enhanced Claude Code functionality
- **claude-code-db**: PostgreSQL database for sessions and history

## Environment Variables

Make sure your `.env` file in the localnet directory contains the required environment variables:

- `CLAUDE_API_KEY` - Your Anthropic API key
- `CLAUDE_CODE_JWT_SECRET` - JWT secret for authentication
- `CLAUDE_CODE_DB_PASSWORD` - Database password

## Integration with Localnet

This build system works with the broader localnet infrastructure. The Claude Code services are integrated into the main docker-compose.yml file and depend on DNS services from the localnet setup.

## Troubleshooting

- If services fail to start, check that the localnet infrastructure is running first
- Use `make logs` to view error messages
- Use `make health-check` to verify service status
- Use `make shell` to access the container directly for debugging

## Related Files

- `tasks.md` - Detailed implementation tasks
- `spec.md` - Complete specifications and requirements
- `Makefile` - Build system commands
- Docker compose file: `../../../apps/active/devops/localnet/services/claude-code/docker-compose.claude-code.yml`
