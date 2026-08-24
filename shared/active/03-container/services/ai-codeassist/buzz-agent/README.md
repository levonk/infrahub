# Buzz Agent Runtime Container

Combines [buzz-acp](https://github.com/block/buzz/tree/main/crates/buzz-acp) (ACP harness) + [devin-cli](https://docs.devin.ai/cli) (AI agent runtime) in one Docker image.

Each agent container runs `buzz-acp`, which:
1. Connects to the Buzz relay as the agent's Nostr identity
2. Spawns `devin acp` as a subprocess (the ACP runtime)
3. Listens for @mentions in channels the agent is a member of
4. Hands messages to `devin acp`, which produces responses
5. Sends responses back to the relay as signed Nostr events

## Image

- **Name**: `localnet-ai-buzz-agent`
- **Dockerfile**: `docker/Dockerfile.buzz-agent`
- **Multi-arch**: `linux/amd64,linux/arm64`
- **Registry**: `100.90.22.85:5000/localnet-ai-buzz-agent:latest`

## Build

```bash
devbox run -- just docker-build-push localnet-ai-buzz-agent
```

## Environment Variables (set per-agent by Ansible)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BUZZ_PRIVATE_KEY` | **yes** | — | Agent's Nostr private key (`nsec1...`) |
| `BUZZ_RELAY_URL` | no | `ws://buzz:3000` | Relay WebSocket URL (internal Docker network) |
| `BUZZ_ACP_AGENT_COMMAND` | no | `devin` | Agent binary to spawn |
| `BUZZ_ACP_AGENT_ARGS` | no | `acp` | Agent arguments |
| `DEVIN_MODEL` | no | `opus` | Devin CLI model (fuzzy name: `opus`, `sonnet`, `gpt`, `swe`) |
| `BUZZ_ACP_IDLE_TIMEOUT` | no | `620` | Idle timeout in seconds |
| `BUZZ_ACP_MAX_TURN_DURATION` | no | `7200` | Max wall-clock per turn |
| `BUZZ_API_TOKEN` | no | — | API token (if relay enforces token auth) |

## Devin CLI Authentication

The Devin CLI reads credentials from `~/.local/share/devin/credentials.toml` inside the container.
This file is mounted from the host (vault-managed) as a read-only volume at
`/home/agent/.local/share/devin/credentials.toml`.

See the `ai-buzz-agent` Ansible role for the volume mount configuration.

## Source

- Buzz: https://github.com/block/buzz (Apache-2.0)
- Devin CLI: https://docs.devin.ai/cli
