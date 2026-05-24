# Kali Linux Base Images for Security Agents

This directory contains Kali Linux-based base images designed for security-focused AI agents in the localnet environment.

## Overview

The Kali Linux base images provide comprehensive security tooling for AI agents that need to perform white/gray/blackhat security operations. These images are designed with proper isolation and security controls.

## Base Images

### 1. `base-kali` - Kali Linux Foundation

**Image**: `localnet-base-kali:latest`

**Purpose**: Basic Kali Linux environment with security tools

**Features**:
- Latest Kali Linux rolling release
- Comprehensive security tool suite
- Python, Go, and Rust development environments
- User permission management
- Health monitoring

**Tools Included**:
- **Network Scanning**: nmap, tcpdump, wireshark-common, dnsutils
- **Web Security**: burpsuite, gobuster, dirb, nikto, sqlmap
- **Exploitation**: metasploit-framework, exploitdb
- **Password Cracking**: john, hashcat
- **Forensics**: autopsy, sleuthkit
- **Reconnaissance**: recon-ng, theharvester, maltego

**Usage**: For agents that need basic security tools without Nix integration

### 2. `base-kalinix` - Kali Linux with Nix

**Image**: `localnet-base-kalinix:latest`

**Purpose**: Kali Linux with Nix package management for enhanced tooling

**Features**:
- All features of base-kali
- Nix package manager integration
- Additional security tools via Nix
- Enhanced development environment
- Package version pinning

**Additional Tools via Nix**:
- Python security packages (scapy, pwntools, cryptography)
- Network analysis tools
- Custom security packages
- Development libraries

**Usage**: For security agents that need additional tools or specific package versions

## Network Architecture

### Isolation Strategy

Security agents run in isolated networks to prevent unauthorized access to localnet services:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Localnet      │    │    DMZ Network   │    │  Agent Network  │
│   Services      │◄──►│  (Optional)      │◄──►│   (Isolated)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
    Trusted Agents        Controlled Access       Security Agents
  (base-debiannix)        (Limited Services)    (base-kalinix)
```

### Network Access Rules

**Agent Network (Isolated)**:
- No direct access to localnet services
- Persistent storage in isolated volumes
- Internet access for external operations
- Optional DMZ access for specific operations

**DMZ Network (Controlled)**:
- Limited access to specific localnet services
- Firewall rules and monitoring
- Audit logging for all access
- Time-limited access sessions

## Usage

### Building Base Images

```bash
# Build base-kali image
cd services/base
docker compose -f docker-compose.base-kali.yml build base-kali

# Build base-kalinix image  
docker compose -f docker-compose.base-kali.yml build base-kalinix
```

### Using Base Images

```dockerfile
# For security agents
FROM localnet-base-kalinix:latest

# Add your agent-specific configuration
COPY your-agent/ /opt/agent/
# ... additional setup
```

### Environment Configuration

```bash
# Load agent environment
source env.agents.template

# Configure agent trust level
export AGENT_TRUST_LEVEL=medium

# Enable DMZ access if needed
export SECURITY_AGENT_DMZ_ACCESS=true
```

## Security Considerations

### Isolation
- Security agents run in isolated networks by default
- No direct access to localnet services
- Persistent storage is isolated from localnet volumes

### Monitoring
- All cross-network access is logged
- Security events are monitored and audited
- Resource usage is tracked and limited

### Access Control
- DMZ access requires explicit configuration
- Time-limited access sessions
- Audit trails for all operations

## Agent Classification

### Standard Agents (base-debiannix)
- **Trust Level**: High
- **Network**: Localnet integration
- **Use Cases**: Code assistance, documentation, analysis

### Security Agents (base-kalinix)
- **Trust Level**: Medium/Low
- **Network**: Agent network + optional DMZ
- **Use Cases**: Red team, penetration testing, security analysis

## Development Guidelines

### Creating Security Agents

1. **Choose Base Image**: Use `base-kalinix` for security agents
2. **Network Isolation**: Configure agent to use agent-network
3. **Resource Limits**: Set appropriate CPU and memory limits
4. **Security Controls**: Implement proper authentication and authorization
5. **Monitoring**: Add health checks and logging

### Example Security Agent

```yaml
# docker-compose.security-agent.yml
services:
  security-agent:
    build:
      context: .
      dockerfile: Dockerfile.security-agent
    networks:
      - agent-network
    volumes:
      - security-agent-data:/data/agent
    environment:
      - AGENT_TRUST_LEVEL=medium
      - SECURITY_AGENT_DMZ_ACCESS=false
    profiles:
      - security
      - agents
```

## Troubleshooting

### Common Issues

1. **Network Access**: Security agents cannot access localnet services by design
2. **Permission Errors**: Check user permissions and volume mounts
3. **Tool Availability**: Verify tools are installed in base image
4. **Resource Limits**: Monitor CPU and memory usage

### Debug Commands

```bash
# Check agent network connectivity
docker compose exec security-agent ping agent-network-gateway

# View agent logs
docker compose logs security-agent

# Check agent health
docker compose exec security-agent /base-kalinix/healthcheck-base-kalinix.sh
```

## Integration with ADR

This implementation follows [ADR-20260322001](../../../internal-docs/adr/adr-20260322001-agent-base-image-selection.md) which defines the strategy for selecting base images for AI agents based on security requirements and operational context.

## Future Enhancements

- Additional specialized security base images
- Automated security scanning for agent images
- Integration with external security platforms
- Advanced monitoring and threat detection
