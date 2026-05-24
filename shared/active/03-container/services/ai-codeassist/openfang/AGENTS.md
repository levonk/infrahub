# OpenFang Security Agent - Agent Documentation

## Overview

OpenFang is a security-focused AI agent designed for autonomous security operations including white/gray/blackhat security testing. This service is specifically configured for security operations with Kali Linux tooling and runs in an isolated network environment.

## Architecture Decision

This implementation follows **[ADR-20260322001](../../../../internal-docs/adr/adr-20260322001-agent-base-image-selection.md)** which defines the strategy for selecting base images for AI agents based on security requirements and operational context.

### Base Image Classification

- **Base Image**: `localnet-base-kalinix` (Kali Linux + Nix)
- **Trust Level**: Medium (Security Agent)
- **Network**: Isolated agent network
- **Access**: Controlled via DMZ when needed

### Security Agent Characteristics

According to the ADR, security agents like OpenFang:
- Run in isolated agent networks by default
- Have optional DMZ access for specific operations
- Use comprehensive security tool suites
- Require audit logging for cross-network activities
- Maintain persistent storage in isolated volumes

## Network Architecture

### Isolation Strategy

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Localnet      │    │    DMZ Network   │    │  Agent Network  │
│   Services      │◄──►│  (Optional)      │◄──►│   (Isolated)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
    Trusted Agents        Controlled Access       OpenFang Agent
  (base-debiannix)        (Limited Services)    (base-kalinix)
```

### Network Access Rules

**Agent Network (Isolated)**:
- No direct access to localnet services
- Persistent storage in isolated volumes
- Internet access for external operations
- Optional DMZ access for controlled operations

**DMZ Access Conditions**:
- Explicit configuration required
- Service-specific firewall rules
- Audit logging for all cross-network access
- Time-limited access sessions

## Security Tool Integration

OpenFang includes comprehensive security tooling from its Kali Linux base:

### Network Security
- **nmap**: Network mapping and port scanning
- **tcpdump**: Packet capture and analysis
- **wireshark**: Network protocol analysis
- **aircrack-ng**: Wireless network security testing

### Web Security
- **burpsuite**: Web application security testing
- **gobuster**: Directory and file brute forcing
- **dirb**: Web content brute forcing
- **nikto**: Web server vulnerability scanning
- **sqlmap**: SQL injection testing

### Exploitation
- **metasploit-framework**: Comprehensive exploitation framework
- **exploitdb**: Exploit database access

### Password Cracking
- **john**: John the Ripper password cracker
- **hashcat**: Advanced password recovery

### Forensics
- **autopsy**: Digital forensics platform
- **sleuthkit**: Forensics toolkit

### Reconnaissance
- **recon-ng**: Web reconnaissance framework
- **theharvester**: OSINT tool
- **maltego**: Open source intelligence platform

## Agent Configuration

### Environment Variables

Key configuration variables for OpenFang:

```bash
# Agent Classification
AGENT_TRUST_LEVEL=medium
SECURITY_AGENT_ISOLATION=true
SECURITY_AGENT_DMZ_ACCESS=false

# OpenFang Configuration
OPENFANG_HOST_PORT=4200
OPENFANG_MAX_AGENTS=10
OPENFANG_AGENT_TIMEOUT=300

# Network Configuration
AGENT_NETWORK_SUBNET=172.20.0.0/16
DMZ_NETWORK_SUBNET=172.21.0.0/16
```

### Trust Level Implications

**Medium Trust Level** means:
- Isolated network access by default
- No direct localnet service access
- Persistent storage in isolated volumes
- Audit logging required for all operations
- Optional DMZ access with explicit configuration

## Usage Guidelines

### Starting OpenFang

Following **[ADR-20260131001](../../../../internal-docs/adr/adr-20260131001-standard-developer-ux-flow.md)** Standard Developer UX Flow:

```bash
# From localnet root directory (REQUIRED)
cd apps/active/devops/localnet

# Start OpenFang with security profile using just
just up --profile security

# Or start all services
just up

# AI Agent/Automated Workflow (devbox run + just-internal)
devbox run just up-internal --profile security
```

**⚠️ CRITICAL**: Always run from localnet root directory - never from services subdirectories!

**Note**: Networks and volumes are automatically created by docker-compose.shared.yml - no manual setup required.

### Environment Setup

This project uses **Devbox** for environment management:

```bash
# Activate devbox shell
devbox shell

# Or run commands directly through devbox
devbox run -- just up --profile security
```

### Enabling DMZ Access

For operations requiring access to localnet services:

```bash
# Enable DMZ access
export SECURITY_AGENT_DMZ_ACCESS=true

# Restart OpenFang with DMZ access
just restart SERVICE=openfang
```

### Monitoring and Logging

Following **[ADR-20260131001](../../../../internal-docs/adr/adr-20260131001-standard-developer-ux-flow.md)** workflow:

```bash
# View OpenFang logs (human developer workflow)
just logs SERVICE=openfang

# AI Agent/Automated Workflow
devbox run just logs-internal SERVICE=openfang

# Check agent health
docker compose exec openfang /openfang/healthcheck-openfang.sh

# Monitor network activity
docker network inspect agent-network

# Build OpenFang service
just build SERVICE=openfang

# AI Agent build workflow
devbox run just build-internal SERVICE=openfang
```

## Security Considerations

### Isolation Requirements

- **Mandatory**: OpenFang must run in isolated agent network
- **Mandatory**: No direct access to localnet services
- **Mandatory**: All operations must be logged and audited
- **Recommended**: Use DMZ access only when necessary

### Resource Limits

OpenFang is configured with resource limits to prevent system impact:

```yaml
deploy:
  resources:
    limits:
      cpus: "2.0"
      memory: 2G
    reservations:
      cpus: "0.5"
      memory: 512M
```

### Audit Requirements

All OpenFang operations are subject to:
- Activity logging
- Cross-network access monitoring
- Resource usage tracking
- Security event recording

## Development Guidelines

### Creating Security Agents

When creating additional security agents:

1. **Use base-kalinix**: All security agents should use `localnet-base-kalinix`
2. **Network Isolation**: Configure to use agent-network
3. **Trust Level**: Set appropriate trust level (medium/low)
4. **DMZ Access**: Implement controlled DMZ access if needed
5. **Audit Logging**: Ensure comprehensive logging

### Example Security Agent Configuration

```yaml
services:
  security-scanner:
    build:
      context: .
      dockerfile: Dockerfile.security-scanner
    networks:
      - agent-network
    environment:
      - AGENT_TRUST_LEVEL=medium
      - SECURITY_AGENT_DMZ_ACCESS=false
    profiles:
      - security
      - agents
```

## Troubleshooting

### Common Issues

1. **Network Access**: OpenFang cannot access localnet services (by design)
2. **Permission Errors**: Check user permissions and volume mounts
3. **Tool Availability**: Verify security tools are installed
4. **Resource Limits**: Monitor CPU and memory usage

### Debug Commands

Following **[ADR-20260131001](../../../../internal-docs/adr/adr-20260131001-standard-developer-ux-flow.md)** workflow:

```bash
# Check agent network connectivity
docker compose exec openfang ping agent-network-gateway

# View OpenFang logs (human developer workflow)
just logs SERVICE=openfang

# AI Agent/Automated Workflow
devbox run just logs-internal SERVICE=openfang

# Check agent health
docker compose exec openfang /openfang/healthcheck-openfang.sh

# Inspect network configuration
docker network inspect agent-network

# Restart OpenFang service
just restart SERVICE=openfang

# AI Agent restart workflow
devbox run just restart-internal SERVICE=openfang
```

## Integration with ADR

This implementation specifically follows the security agent guidelines defined in **[ADR-20260322001](../../../../internal-docs/adr/adr-20260322001-agent-base-image-selection.md)**:

- **Base Image Selection**: Uses `localnet-base-kalinix` for security operations
- **Network Isolation**: Implements agent network isolation
- **Trust Classification**: Medium trust level with appropriate controls
- **Access Control**: DMZ access with explicit configuration and logging
