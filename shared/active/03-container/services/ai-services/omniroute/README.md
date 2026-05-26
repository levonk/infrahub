# OmniRoute Service

OmniRoute is a free AI gateway that provides one endpoint to connect to 177+ AI providers (50+ free). It enables connecting tools like Claude Code, Codex, Cursor, Cline & Copilot to free Claude/GPT/Gemini models.

## Features

- **Unified API**: Single endpoint for 177+ AI providers
- **Free Providers**: 50+ free AI providers available
- **Smart Routing**: Automatic provider selection and fallback
- **Token Compression**: RTK+Caveman stacked compression saves 15-95% tokens
- **MCP/A2A Support**: Model Context Protocol and Agent-to-Agent protocol
- **Multimodal APIs**: Support for text, image, audio, and video

## Service Configuration

- **Container Name**: `localnet-ai-omniroute`
- **Image**: `localnet-ai-omniroute:latest` (built from `diegosouzapw/omniroute:latest`)
- **Port**: 20128 (default)
- **Data Volume**: `/opt/localnet/volumes/omniroute` (configurable via `AI_OMNIROUTE_DATA_PATH`)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AI_OMNIROUTE_HOST_PORT` | Host port for OmniRoute API | 20128 |
| `AI_OMNIROUTE_CONTAINER_PORT` | Container port for OmniRoute API | 20128 |
| `AI_OMNIROUTE_DATA_PATH` | Host path for data volume | `/opt/localnet/volumes/omniroute` |

## Usage

### Start the Service

```bash
# From localnet root
cd /Users/micro/p/gh/levonk/localnet/shared/active/03-container
devbox run -- docker compose -f services/ai-services/docker-compose.ai.yml --profile all up omniroute -d --build
```

### Access the Service

- **Dashboard**: http://localhost:20128
- **API Endpoint**: http://localhost:20128/v1

### Connect a Provider

1. Open the dashboard at http://localhost:20128
2. Navigate to Providers
3. Connect a free provider (e.g., Kiro AI for free Claude, or OpenCode Free)
4. Copy the API key from Dashboard → Endpoints

### Configure Your AI Tool

Use these settings in your AI coding tool:

```
Base URL: http://localhost:20128/v1
API Key: [copy from Dashboard → Endpoints]
Model: auto (zero-config smart routing)
```

## Security Features

- Non-root execution (runs as `cuser` with UID/GID 1000)
- Read-only filesystem
- No new privileges flag
- Custom healthcheck
- Graceful shutdown handling

## Health Check

The service includes a custom healthcheck that verifies:
- API endpoint is responding (`/v1/models`)
- Port is accessible

Healthcheck runs every 30 seconds with a 10-second timeout and 3 retries.

## Building

To build the image locally:

```bash
cd /Users/micro/p/gh/levonk/localnet/shared/active/03-container/services/ai-services/omniroute
docker build -f docker/Dockerfile.omniroute -t localnet-ai-omniroute:latest .
```

## Logs

View logs for the omniroute service:

```bash
docker logs -f localnet-ai-omniroute
```

## Troubleshooting

### Service not starting

Check the logs:
```bash
docker logs localnet-ai-omniroute
```

### Port already in use

Change the host port in your environment:
```bash
export AI_OMNIROUTE_HOST_PORT=20129
```

### Permission issues

The service runs as non-root user `cuser` (UID/GID 1000). Ensure the data volume has correct permissions.

## References

- [OmniRoute GitHub](https://github.com/diegosouzapw/OmniRoute)
- [OmniRoute Documentation](https://github.com/diegosouzapw/OmniRoute/blob/main/docs)
- [Docker Guide](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/DOCKER_GUIDE.md)
