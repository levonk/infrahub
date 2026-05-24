# HAPI Services - Remote AI Agent Access

HAPI (Happy AI Programming Interface) enables remote access to AI coding agents (Claude Code, OpenAI Codex, Google Gemini) through a centralized server with web and mobile interfaces.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Machine                         │
│                                                         │
│  ┌─────────────┐    Socket.IO    ┌─────────────┐       │
│  │ HAPI Client│◄───────────────►│ HAPI Server │       │
│  │ + AI Agent │                 │ + SQLite    │       │
│  └─────────────┘                 └──────┬──────┘       │
│         ▲                              │ SSE          │
│         │ spawn                       ▼              │
│  ┌──────┴─────┐                 ┌─────────────┐       │
│  │ HAPI Runner│◄────RPC────────►│   Web App   │       │
│  └────────────┘                 └─────────────┘       │
└─────────────────────────────────────────────────────────┘
                    │
           [Tunnel / Public URL]
                    │
              ┌─────▼─────┐
              │ Phone/Web │
              └───────────┘
```

## Services

### HAPI Server
- **Purpose**: Central hub for session management, persistence, and remote access
- **Base Image**: `localnet-base-debian`
- **Port**: 3006
- **Features**:
  - SQLite database for session storage
  - Socket.IO for real-time client communication
  - REST API + SSE for web interface
  - Optional Telegram bot integration
  - End-to-end encrypted relay support

### HAPI Client
- **Purpose**: Interactive development environment with AI agents
- **Base Image**: `localnet-base-dev`
- **Features**:
  - Full development environment (inherited from base-dev)
  - Claude Code, OpenAI Codex, Google Gemini CLI pre-installed
  - Automatic server connection and health checking
  - Session synchronization with server

## Quick Start

### 1. Start HAPI Server
```bash
# Start server with public relay (easiest)
make hapi-server-up

# Or start server only
docker-compose -f services/ai-codeassist/docker-compose.hapi.yml up -d hapi-server
```

The server will display:
- URL for web access
- QR code for mobile scanning
- Generated CLI API token

### 2. Connect HAPI Client
```bash
# Start interactive client
make hapi-client-up

# Or start client manually
docker-compose -f services/ai-codeassist/docker-compose.hapi.yml run --rm hapi-client
```

### 3. Start Using HAPI
```bash
# Inside the client container
hapi  # Start interactive session
```

## Configuration

### Environment Variables

#### Server Configuration
```bash
# Required
CLI_API_TOKEN=your-secret-token          # Authentication secret
HAPI_LISTEN_HOST=0.0.0.0                # Bind address
HAPI_LISTEN_PORT=3006                    # Port

# Optional
HAPI_PUBLIC_URL=https://your-domain.com  # Public URL for external access
TELEGRAM_BOT_TOKEN=your-bot-token        # Telegram integration
ELEVENLABS_API_KEY=your-key              # Voice assistant
CORS_ORIGINS=*                          # Allowed origins
```

#### Client Configuration
```bash
# Required
CLI_API_TOKEN=your-secret-token          # Must match server
HAPI_API_URL=http://hapi-server:3006     # Server URL
```

### Deployment Options

#### Option 1: Public Relay (Recommended)
```bash
# Server
hapi server --relay

# Automatic end-to-end encryption via WireGuard + TLS
# Works behind NAT/firewalls
# No configuration required
```

#### Option 2: Self-Hosted Tunnel
```bash
# Cloudflare Tunnel
export HAPI_PUBLIC_URL="https://your-tunnel.trycloudflare.com"
hapi server

# Tailscale
hapi server  # Access via Tailscale IP
```

#### Option 3: Direct Public IP
```bash
export HAPI_PUBLIC_URL="https://your-server.com"
hapi server
```

## Usage Examples

### Local Development
```bash
# Start server locally
make hapi-server-up

# Connect client in same terminal
make hapi-client-up
```

### Remote Access
```bash
# Start server with relay
HAPI_PUBLIC_URL=https://your-server.com make hapi-server-up

# Connect from any machine
HAPI_API_URL=https://your-server.com:3006 hapi
```

### Mobile Access
1. Start server with `--relay`
2. Scan QR code with phone
3. Control sessions from mobile web app

## Makefile Commands

```bash
# Build and start all HAPI services
make hapi-up

# Start only server
make hapi-server-up

# Start interactive client
make hapi-client-up

# Stop all HAPI services
make hapi-down

# Rebuild HAPI images
make hapi-rebuild

# View HAPI logs
make hapi-logs

# Clean HAPI data
make hapi-clean
```

## Data Persistence

### Server Data
- **Location**: `/root/.hapi/` in server container
- **Contents**:
  - `hapi.db` - SQLite database
  - `settings.json` - Configuration
  - `logs/` - Log files
- **Volume**: `localnet-hapi-data`

### Client Workspace
- **Location**: `/workspace` in client container
- **Volume**: `localnet-hapi-client-workspace`

## Security

### Authentication
- Shared `CLI_API_TOKEN` between client and server
- Token auto-generated if not provided
- HTTPS/TLS encryption for remote access

### Network Security
- Server binds to `0.0.0.0` for remote access
- Client connects via internal Docker network
- Optional tunneling for secure external access

### Container Security
- Non-root user execution
- Minimal attack surface
- Health checks and monitoring

## Troubleshooting

### Server Issues
```bash
# Check server logs
make hapi-logs SERVICE=hapi-server

# Check server health
curl http://localhost:3006/health

# Regenerate token
docker-compose -f docker-compose.hapi.yml exec hapi-server \
  hapi server --generate-token
```

### Client Issues
```bash
# Check client logs
make hapi-logs SERVICE=hapi-client

# Test server connection
docker-compose -f docker-compose.hapi.yml exec hapi-client \
  curl -f ${HAPI_API_URL}/health

# Reset client configuration
make hapi-clean
make hapi-up
```

### Network Issues
```bash
# Check Docker network
docker network ls | grep localnet

# Test connectivity
docker-compose -f docker-compose.hapi.yml exec hapi-client \
  ping hapi-server

# Rebuild network
make clean
make up
```

## Integration with AI Agents

HAPI wraps existing AI agent CLIs:

### Claude Code
```bash
# Prerequisites: claude CLI installed
hapi  # Uses claude automatically
```

### OpenAI Codex
```bash
# Prerequisites: codex CLI installed
hapi  # Uses codex automatically
```

### Google Gemini
```bash
# Prerequisites: gemini CLI installed
hapi  # Uses gemini automatically
```

## Advanced Features

### Background Runner
```bash
# Start background service for remote spawning
hapi runner start

# Check runner status
hapi runner status

# View runner logs
hapi runner logs
```

### Voice Assistant
```bash
# Configure ElevenLabs
export ELEVENLABS_API_KEY=your-key
export ELEVENLABS_AGENT_ID=your-agent

# Start server with voice support
hapi server --relay
```

### Telegram Integration
```bash
# Configure bot
export TELEGRAM_BOT_TOKEN=your-token
export HAPI_PUBLIC_URL=https://your-domain.com

# Start server with Telegram support
hapi server
```

## Development

### Building Images
```bash
# Build server image
docker build -t localnet-hapi-server ./hapi-server

# Build client image
docker build -t localnet-hapi-client ./hapi-client
```

### Testing
```bash
# Test server locally
docker run -p 3006:3006 localnet-hapi-server

# Test client connection
docker run --rm -e HAPI_API_URL=http://host.docker.internal:3006 \
  localnet-hapi-client hapi --help
```

## Support

- **Documentation**: [HAPI Official Docs](https://github.com/tiann/hapi)
- **Issues**: [GitHub Issues](https://github.com/tiann/hapi/issues)
- **Community**: [Discussions](https://github.com/tiann/hapi/discussions)

## License

This HAPI service configuration follows the AGPL-3.0 license, consistent with the upstream HAPI project.
