# Forge - Tool Calling Reliability Layer

Forge is a reliability layer for self-hosted LLM tool-calling. It sits between the Privacy Orchestrator and Headroom in the AI analytics pipeline, fixing tool calling issues in AI requests.

## Purpose

Forge applies guardrails to LLM tool calls:
- **Response validation** - checks tool calls against the tools array
- **Rescue parsing** - extracts tool calls from wrong formats (JSON in code fences, Mistral `[TOOL_CALLS]`, Qwen XML)
- **Retry loop** - retries inference with corrective messages on validation failure
- **Synthetic `respond` tool** - ensures models use tools instead of bare text

## Pipeline Position

```
Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
     (PII Detection)    (Compression)   (Routing)       (Tool Calling Fixer)    (Pre-Egress)    (Security)    (Privacy)
```

## Configuration

### Environment Variables

- `AI_CODEASSIST_FORGE_PUID` - User ID (default: 1000)
- `AI_CODEASSIST_FORGE_PGID` - Group ID (default: 1000)
- `AI_CODEASSIST_FORGE_TZ` - Timezone (default: UTC)
- `AI_CODEASSIST_FORGE_HOST_PORT` - Host port (default: 8083)
- `AI_CODEASSIST_FORGE_CONTAINER_PORT` - Container port (default: 8081)
- `AI_CODEASSIST_FORGE_BACKEND_URL` - Upstream backend URL (default: http://omniroute:20128)
- `AI_CODEASSIST_FORGE_MAX_RETRIES` - Maximum retry attempts (default: 3)
- `AI_CODEASSIST_FORGE_REASONING_REPLAY` - Reasoning replay policy (default: none)

## Usage

### Build and Start

```bash
cd /Users/micro/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-codeassist-forge up -d --build
```

### View Logs

```bash
docker logs forge --tail=50 -f
```

### Health Check

```bash
curl http://localhost:8083/health
```

## API Endpoints

Forge runs a proxy server that speaks both OpenAI chat-completions and Anthropic Messages APIs:

- **OpenAI API**: `http://localhost:8083/v1/chat/completions`
- **Anthropic API**: `http://localhost:8083/v1/messages`

## References

- Project: https://github.com/antoinezambelli/forge
- Documentation: https://github.com/antoinezambelli/forge#proxy-server
