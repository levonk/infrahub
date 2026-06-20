# Headroom - Context Compression Layer for AI Agents

## Overview

Headroom is a context compression layer for AI agents that reduces token usage by 60-95% while maintaining accuracy. This container runs headroom as a proxy service that sits upstream of iron-proxy in the proxy chain.

**Proxy Chain Architecture:**
```
Tailscale Clients → Headroom (8787) → Iron-Proxy (8080) → Internet
```

**Key Features:**
- **Context Compression**: Reduces LLM token usage by 60-95% using multiple compression algorithms
- **Proxy Mode**: Drop-in proxy that requires no code changes
- **Output Token Reduction**: Reduces what the model writes back (optional)
- **Cross-Agent Memory**: Shared memory store across different AI agents
- **Reversible Compression**: Originals cached for retrieval on demand

**Source**: https://github.com/chopratejas/headroom

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Network connectivity to iron-proxy (upstream proxy)

### Configuration

Set the upstream proxy in `.env`:

```bash
AI_CODEASSIST_HEADROOM_UPSTREAM_PROXY=http://iron-proxy:8080
```

### Build and Run

```bash
# Build the service
docker-compose build

# Start the service
docker-compose up -d

# View logs
docker-compose logs -f
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HEADROOM_PORT` | Headroom proxy port | 8787 |
| `HEADROOM_HOST` | Headroom bind address | 0.0.0.0 |
| `HEADROOM_DATA_DIR` | Data directory for cache/memory | /data |
| `UPSTREAM_PROXY` | Upstream proxy (iron-proxy) | http://iron-proxy:8080 |
| `HEADROOM_OUTPUT_SHAPER` | Enable output token reduction | 0 |

### Ports

- **8787**: Headroom proxy port (exposed to Tailscale clients)

### Proxy Chain Integration

Headroom is designed to work in a proxy chain with iron-proxy:

1. **Tailscale clients** connect to headroom on port 8787
2. **Headroom** compresses LLM requests/responses
3. **Headroom** forwards to iron-proxy on port 8080
4. **Iron-Proxy** applies egress filtering and secret injection
5. **Iron-Proxy** forwards to internet

### Network Configuration

The container connects to two networks:
- `headroom-network`: Isolated network for headroom services
- `proxy-chain-network`: Shared network for proxy chain communication

## Usage

### Route AI Agents Through Headroom

Configure your AI agent to use headroom as its HTTP proxy:

```bash
export HTTP_PROXY=http://headroom:8787
export HTTPS_PROXY=http://headroom:8787
```

For Tailscale clients, use the host's IP address:

```bash
export HTTP_PROXY=http://<tailscale-ip>:8787
export HTTPS_PROXY=http://<tailscale-ip>:8787
```

### Enable Output Token Reduction

Set the environment variable to enable output token reduction:

```bash
AI_CODEASSIST_HEADROOM_OUTPUT_SHAPER=1
```

This reduces the tokens the model writes back by:
- Appending "be terse" notes to system prompts
- Reducing thinking effort on routine steps
- Skipping deep thinking on file reads and passing tests

## Monitoring

### Logs

View logs:

```bash
docker-compose logs -f headroom
```

### Health Check

The container includes a health check:

```bash
curl http://localhost:8787/health
```

## Security

### Container Hardening

- **Base Image**: Alpine 3.20 (minimal attack surface)
- **User**: Non-root (headroom:headroom, UID/GID 1000)
- **Capabilities**: Dropped all capabilities
- **Filesystem**: Read-only root filesystem
- **Networks**: Isolated network configuration

### Best Practices

- No privileged containers
- No host network access
- No Docker socket mounting
- Resource limits enforced
- Proper secret management via upstream proxy

## Deployment

### Docker Compose

```yaml
services:
  headroom:
    build:
      context: .
      dockerfile: Dockerfile.headroom
    container_name: headroom
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      - UPSTREAM_PROXY=http://iron-proxy:8080
      - HEADROOM_OUTPUT_SHAPER=0
    networks:
      - proxy-chain-network
```

### Ansible Deployment

Deploy to OCI cloud host using the provided Ansible playbooks:

```bash
# Deploy headroom service
ansible-playbook playbooks/deploy-headroom.yml
```

## Troubleshooting

### Common Issues

1. **Cannot connect to upstream proxy**
   ```bash
   # Check if iron-proxy is running
   docker ps | grep iron-proxy
   
   # Check network connectivity
   docker exec headroom ping iron-proxy
   ```

2. **High memory usage**
   ```bash
   # Check headroom data directory size
   docker exec headroom du -sh /data
   
   # Clear cache if needed
   docker exec headroom rm -rf /data/cache/*
   ```

3. **Port already in use**
   ```bash
   # Find what's using the port
   lsof -i :8787
   
   # Change port in .env
   AI_CODEASSIST_HEADROOM_HOST_PORT=8788
   ```

## Performance

### Expected Compression Ratios

- **Code search**: 92% reduction (17,765 → 1,408 tokens)
- **SRE incident debugging**: 92% reduction (65,694 → 5,118 tokens)
- **GitHub issue triage**: 73% reduction (54,174 → 14,761 tokens)
- **Codebase exploration**: 47% reduction (78,502 → 41,254 tokens)

### Accuracy

Headroom maintains accuracy on standard benchmarks:
- GSM8K Math: ±0.000 delta
- TruthfulQA: +0.030 improvement
- SQuAD v2 QA: 97% accuracy with 19% compression

## Architecture

### Compression Pipeline

```
Your Agent → Headroom → ContentRouter → Compressor → LLM
              ↓            ↓              ↓
           CacheAligner  SmartCrusher   CodeCompressor
                         Kompress-base   (AST)
```

### Components

- **ContentRouter**: Detects content type, selects appropriate compressor
- **SmartCrusher**: JSON compression
- **CodeCompressor**: AST-based code compression
- **Kompress-base**: ML-based text compression
- **CacheAligner**: Stabilizes prefixes for KV cache hits
- **CCR**: Reversible compression with retrieval

## References

- [Headroom Documentation](https://headroom-docs.vercel.app/docs)
- [Headroom GitHub](https://github.com/chopratejas/headroom)
- [Proxy Chain Architecture](../iron-proxy/README.md)