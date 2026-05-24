# OpenFang Security Agent Service

OpenFang is an open-source Agent Operating System built in Rust that provides autonomous agents that work for you on schedules, building knowledge graphs, monitoring targets, and reporting results. This deployment is specifically configured for security operations with Kali Linux tooling.

## Overview

OpenFang is not a chatbot framework or a Python wrapper around an LLM. It is a full operating system for autonomous agents, built from scratch in Rust. The entire system compiles to a single ~32MB binary that provides:

- **Autonomous Agents**: Pre-built "Hands" that run independently on schedules
- **Web Dashboard**: Accessible at http://localhost:4200
- **OpenAI-Compatible API**: Drop-in replacement for existing tools
- **Multi-LLM Support**: 27 providers with 123+ models
- **Knowledge Graphs**: Automatic knowledge building and management
- **Security Operations**: White/gray/blackhat security capabilities

## Security-Focused Architecture

This OpenFang deployment is based on **Kali Linux with Nix** (`localnet-base-kalinix`) and includes:

### Security Tool Integration
- **Network Security**: nmap, tcpdump, wireshark, aircrack-ng
- **Web Security**: burpsuite, gobuster, dirb, nikto, sqlmap
- **Exploitation**: metasploit-framework, exploitdb
- **Password Cracking**: john, hashcat
- **Forensics**: autopsy, sleuthkit
- **Reconnaissance**: recon-ng, theharvester, maltego

### Network Isolation
OpenFang runs in an **isolated agent network** for security:
- **No direct access** to localnet services by default
- **Persistent storage** in isolated volumes
- **Optional DMZ access** for controlled operations
- **Audit logging** for all cross-network activities

### Trust Level
- **Classification**: Security Agent (Medium Trust)
- **Network**: Isolated agent network
- **Access**: Controlled via DMZ when needed

## Features

### Hands: Agents That Actually Do Things

OpenFang's core innovation is "Hands" - pre-built autonomous capability packages that run independently without requiring user prompts:

- **Researcher Hand**: Researches competitors, builds knowledge graphs, scores findings
- **Browser Hand**: Web automation and monitoring capabilities
- **Coder Hand**: Code generation and development assistance
- And more...

### LLM Provider Support

OpenFang supports 27+ LLM providers including:
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Google Gemini
- Groq, DeepSeek, OpenRouter
- And many more...

### API Compatibility

OpenFang provides a drop-in OpenAI-compatible API:

```bash
curl -X POST localhost:4200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "researcher",
    "messages": [{"role": "user", "content": "Analyze Q4 market trends"}],
    "stream": true
  }'
```

## Usage in LocalNet

### Starting OpenFang

```bash
# From the localnet root directory
cd apps/active/devops/localnet

# Setup agent networks (first time only)
./scripts/setup-agent-networks.sh

# Start OpenFang with other security agents
just up --profile security

# Or start all services
just up
```

### Accessing OpenFang

- **Web Dashboard**: http://localhost:4200
- **API Endpoint**: http://localhost:4200/v1/chat/completions
- **Health Check**: http://localhost:4200/health

### Network Access

OpenFang runs in an isolated network. To enable DMZ access:

```bash
# Enable DMZ access
export SECURITY_AGENT_DMZ_ACCESS=true

# Restart OpenFang with DMZ access
just restart SERVICE=openfang
```

### Configuration

OpenFang can be configured through environment variables:

#### LLM Provider Configuration

```bash
# OpenAI
export OPENAI_API_KEY="your-openai-api-key"

# Anthropic
export ANTHROPIC_API_KEY="your-anthropic-api-key"

# Google Gemini
export GEMINI_API_KEY="your-gemini-api-key"
```

#### Service Configuration

```bash
# Agent limits
export OPENFANG_MAX_AGENTS=10
export OPENFANG_AGENT_TIMEOUT=300

# Authentication (optional)
export OPENFANG_ENABLE_AUTH=true
export OPENFANG_API_KEY="your-api-key"
```

### Volume Structure

OpenFang uses persistent volumes for data storage:

- `openfang-data`: Agent data and knowledge graphs
- `openfang-config`: Configuration files
- `openfang-storage`: File storage and uploads
- `openfang-logs`: Application logs
- `openfang-home`: User home directory

## Security

OpenFang includes comprehensive security measures:

- **Non-root execution**: Runs as dedicated user with limited privileges
- **Network isolation**: Configured for localnet network access
- **Resource limits**: CPU and memory constraints
- **Health monitoring**: Built-in health checks and monitoring
- **Secure defaults**: Secure-by-default configuration

## Development

### Building the Service

```bash
# Build the OpenFang container
docker compose -f services/ai-codeassist/openfang/openfang/docker-compose.openfang.yml build openfang
```

### Viewing Logs

```bash
# View OpenFang logs
docker compose logs -f openfang

# Or use the justfile
just logs SERVICE=openfang
```

### Health Checks

```bash
# Check service health
docker compose exec openfang /openfang/healthcheck-openfang.sh

# Or use the justfile
just health-check
```

## Integration with Other Services

OpenFang integrates with the localnet environment:

- **Base Services**: Uses nix-sidecar for package management
- **Network**: Connected to localnet and codeassist networks
- **Storage**: Uses shared volumes for persistence
- **Monitoring**: Health checks integrated with localnet monitoring

## Troubleshooting

### Common Issues

1. **Service won't start**: Check if base services are running
   ```bash
   just base-up
   just up --profile ai-codeassist
   ```

2. **Can't access dashboard**: Check port mapping
   ```bash
   docker compose ps openfang
   ```

3. **LLM provider errors**: Verify API keys are set correctly
   ```bash
   docker compose exec openfang env | grep API_KEY
   ```

### Logs and Debugging

```bash
# View detailed logs
docker compose logs --tail=100 openfang

# Check container status
docker compose ps openfang

# Execute commands in container
docker compose exec openfang /bin/bash
```

## Architecture

OpenFang follows the localnet service patterns:

- **Dockerfile**: Multi-stage build with security hardening
- **Entrypoint**: Comprehensive initialization and startup script
- **Health Check**: Multi-layer health monitoring
- **Configuration**: Template-based configuration with environment variables
- **Integration**: Full integration with localnet infrastructure

## License

OpenFang is licensed under MIT License. See the [OpenFang GitHub repository](https://github.com/RightNow-AI/openfang) for more details.

## Support

- **Documentation**: [https://openfang.sh](https://openfang.sh)
- **GitHub**: [https://github.com/RightNow-AI/openfang](https://github.com/RightNow-AI/openfang)
- **Discord**: [https://discord.gg/sSJqgNnq6X](https://discord.gg/sSJqgNnq6X)
