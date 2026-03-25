# LocalNet Development Environment - Agent Instructions

This document follows **[ADR-20260322002](../internal-docs/adr/adr-20260322002-docker-compose-profile-strategy.md)** for Docker Compose profile-based service organization and **[ADR-20260322003](../internal-docs/adr/adr-20260322003-memory-management-local-task-tracking.md)** for memory management and task tracking.

If you're working on Nix containers, see the documentation at:

- /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/internal-docs/requirements/nix/

## 🚀 Environment Setup

This project uses **Devbox** for environment management with integrated memory management tools (qmd, tkr, Obsidian). Follow these steps:

### 1. Setup Devbox Environment
```bash
# Ensure you're in the correct directory
cd apps/active/devops/localnet

# Start devbox shell (installs just, yq-go, jq, qmd, tkr, obsidian)
devbox shell

# Or run commands directly through devbox
devbox run -- just base-up-internal
```

### 2. Available Commands

**Profile-Based Service Management (NEW)**:
```bash
# Profile-based service orchestration (ADR-20260322002)
just up-agents                    # Start AI/agent services
just up-base01                    # Production base services
just up-core-nix                  # Core infrastructure only
just up-localnet                  # Full localnet environment

# Environment-specific deployments
COMPOSE_ENV=production just up-base01
COMPOSE_ENV=testing just up-agents

# Multi-profile combinations
just up-core-nix                  # Core + Nix services
just up-prod                      # Production environment
```

**Memory Management & Task Tracking (NEW)**:
```bash
# Search documentation and memory
just doc-search "authentication"
just doc-search "database patterns"

# Task management with tkr
just tasks                         # List open tasks
just task-ready                    # Get next available task
just task-start                   # Start working on task
```

**Traditional Commands (backward compatible)**:
```bash
# Primary workflow: just → devbox run -- just-internal
just base-up        # → devbox run -- just base-up-internal
just up             # → devbox run -- just up-internal
just down           # → devbox run -- just down-internal
just build          # → devbox run -- just build-internal
just clean          # → devbox run -- just clean-internal
just logs           # → devbox run -- just logs-internal
just health-check   # → devbox run -- just health-check-internal
just test           # → devbox run -- just test-internal
just bootstrap      # → devbox run -- just bootstrap-internal
```

### 3. ADR Compliance Notes

This project follows multiple ADRs for standardized workflows:

- **ADR-20260131001**: Standard Developer UX Flow (`direnv → devbox → just (*-internal)`)
- **ADR-20260322002**: Docker Compose Profile-Based Service Organization
- **ADR-20260322003**: Memory Management and Local Task Tracking

The justfile includes `-internal` recipe variants to comply with ADR-20260131001:
- All main recipes have corresponding `-internal` variants
- `-internal` recipes delegate to their main counterparts
- Enables parent devbox.json to call `bootstrap-internal` and other `-internal` targets

### 4. Why Devbox with Memory Tools?
- **Consistent Environment**: Provides consistent development environment across all projects
- **Integrated Tooling**: Includes required tools (just, yq-go, jq, qmd, tkr, obsidian)
- **Memory Management**: Built-in qmd for documentation search, tkr for task tracking
- **Knowledge Graph**: Obsidian for interconnected knowledge management
- **ADR Compliance**: Follows monorepo standards from ADR-20260131001

## 🔄 Profile-Based Service Organization

Following **[ADR-20260322002](../internal-docs/adr/adr-20260322002-docker-compose-profile-strategy.md)**, services are organized into profiles for better debugging and management:

### Available Profiles

```bash
# Core Infrastructure
just up-core                      # Core services (networks, shared resources)
just up-nix                       # Nix package management
just up-dns                       # DNS resolution services

# Base Environments
just up-base01                    # Production base infrastructure
just up-base02                    # Development base infrastructure

# Application Services
just up-agents                    # AI and agent services (OpenFang)
just up-security                  # Security services and monitoring

# Combined Environments
just up-localnet                  # Full localnet environment (default)
just up-core-nix                  # Core infrastructure + Nix
just up-prod                      # Production environment
just up-test                      # Testing environment
```

### Environment-Specific Deployment

```bash
# Production environment
COMPOSE_ENV=production just up-base01

# Development environment (default)
COMPOSE_ENV=development just up-localnet

# Testing environment
COMPOSE_ENV=testing just up-agents
```

### Debugging with Profiles

```bash
# Debug specific service
docker compose --profile nix up nix-sidecar

# Debug service cluster
docker compose --profile agents up

# Show logs for profile
docker compose --profile nix logs --tail=50

# Use justfile for ADR-compliant debugging
just up-nix                        # Start Nix services
just logs                          # View all logs
```

## 🧠 Memory Management & Task Tracking

Following **[ADR-20260322003](../internal-docs/adr/adr-20260322003-memory-management-local-task-tracking.md)**:

### Memory Search with qmd

```bash
# Search documentation and knowledge base
just doc-search "authentication patterns"
just doc-search "database design"
just doc-search "kali security tools"

# Show all indexed content
just doc-search
```

### Task Management with tkr

```bash
# View available tasks
just tasks

# Get next actionable task
just task-ready

# Start working on task
just task-start

# Add notes to current task
tkr add-note <task-id> "Working on authentication flow"
```

### Knowledge Management with Obsidian

The `memory/` directory contains organized knowledge:
- `01-projects/` - Project-specific knowledge
- `02-decisions/` - Architecture decisions and rationale
- `03-patterns/` - Design patterns and solutions
- `04-learnings/` - Lessons learned and insights

## 🎯 Integrated Workflow

### Daily Development Workflow

```bash
# 1. Enter project (direnv activates devbox with memory tools)
cd apps/active/devops/localnet

# 2. Check available tasks
just tasks

# 3. Search memory for context
just doc-search "security agent configuration"

# 4. Start specific service cluster (ADR-20260322002)
just up-agents

# 5. Start working on task
just task-start

# 6. Work with full context (qmd + Obsidian + tkr)
```

## ⚠️ CRITICAL: Directory Requirements

**🚨 NEVER run docker compose commands from services/ subdirectories!**

**ALWAYS run from the localnet root directory:**

```bash
cd apps/active/devops/localnet
```

**Why this is critical:**

- Docker compose files use relative paths (`../../`, `../`) that resolve differently from subdirectories
- Environment variables are loaded relative to the localnet root
- Volume paths and network configurations depend on the correct working directory
- Running from services/ will cause "file not found" and "path resolution" errors

**❌ WRONG (will fail):**

```bash
cd services/base
docker compose up  # ← FAILS - wrong directory!
```

**✅ CORRECT:**

```bash
cd apps/active/devops/localnet
just base-up  # ← Uses correct paths and env vars
```

## ⚠️ IMPORTANT: Use Profile-Based Service Management

**PREFER the new profile-based approach** for better debugging and service isolation:

```bash
# RECOMMENDED: Profile-based service management (ADR-20260322002)
just up-agents                    # Start AI/agent services
just up-base01                    # Production base services
just up-core-nix                  # Core infrastructure only

# LEGACY: Traditional justfile commands (still work)
just up                           # Start all services
just base-up                      # Start base services
```

### When to Use Each Approach

**Use Profile-Based Services**:
- Debugging specific service clusters
- Testing individual components
- Environment-specific deployments
- Isolating service dependencies

**Use Traditional Commands**:
- Full system startup
- Legacy compatibility
- Simple workflows

## 🔄 Service Organization (Profile-Based)

Following **[ADR-20260322002](../internal-docs/adr/adr-20260322002-docker-compose-profile-strategy.md)**, services are organized into logical profiles:

### Profile Hierarchy

```
ALL (Production/Development)
├── BASE01/BASE02 (Base Infrastructure)
│   ├── CORE (Essential services)
│   ├── NIX (Package management)
│   └── DNS (Resolution services)
├── AGENTS (AI services)
│   └── OpenFang security agent
└── SECURITY (Security monitoring)
```

### Profile Usage Examples

```bash
# Start specific service cluster
just up-core-nix                  # Core infrastructure only
just up-agents                    # AI and agent services
just up-security                  # Security services

# Environment-specific deployment
COMPOSE_ENV=production just up-base01
COMPOSE_ENV=development just up-localnet

# Debug specific service
docker compose --profile nix up nix-sidecar
docker compose --profile agents up openfang
```

## Common Workflows

### Development Setup

```bash
# Start everything in proper order
just up

# View logs for all services
just logs

# View logs for specific service
just logs SERVICE=nix-sidecar
```

### Troubleshooting

```bash
# Clean restart
just down
just up

# Rebuild specific service
just rebuild SERVICE=nix-sidecar

# Check service health
just health
```

### Development Iteration

```bash
# After making changes to a service:
just rebuild SERVICE=<service-name>

# Or for full rebuild:
just clean
just up
```

## What Happens If You Don't Use the Justfile

1. **Missing Environment Variables** - Services fail to start or use wrong configurations
2. **Dependency Failures** - Services start before their dependencies are ready
3. **Network Issues** - Containers can't communicate with each other
4. **Volume Problems** - Shared data isn't properly initialized
5. **Port Conflicts** - Services try to use already-allocated ports
6. **🚨 PATH RESOLUTION ERRORS** - Running from services/ subdirectories breaks all relative paths (`../../`, `../`) in compose files, causing "file not found" errors for includes, volumes, and build contexts

## Environment Files

- `env.template` - Base configuration (version controlled)
- `env.local` - Local overrides (gitignored)
- `.env` - Generated file with combined environment

Never modify `.env` directly - it's generated by the justfile.

## Service Dependencies

```text
base-nix-sidecar (foundation)
    ↓
dns services (coredns, dnsdist, dnscrypt-proxy)
    ↓
artifact services (harmonia, ncps)
```

Each layer depends on the layer below it. The justfile ensures this ordering is respected.

## Troubleshooting Common Issues

### "Service unhealthy" errors

```bash
# Check what's wrong
docker inspect <container-name> --format='{{json .State.Health}}'

# Restart with proper ordering
just down
just up
```

### "Port already in use" errors

```bash
# Clean up everything
just clean
just up
```

### Environment variable issues

```bash
# Check environment loading
just debug-env

# Regenerate environment files
just clean-env
just up
```

### Container startup issues

**Current Issue: nix-sidecar container missing `/bin/sh`**

If you see this error:
```
exec /bin/sh: no such file or directory
```

**Root Cause:** The nix-sidecar container is built from a minimal base image that doesn't include `/bin/sh`.

**Solution Path:** 
1. Check the Dockerfile: `services/base/nix-sidecar/Dockerfile.nix-sidecar`
2. Check the entrypoint: `services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh`
3. Ensure proper user permission dropping as specified in the container configuration

**Temporary Workaround:**
```bash
# Clean and restart
just clean
just base-up
```

## Remember

**Always use `just up`** - it handles the complex orchestration that Docker Compose alone cannot manage due to the multi-environment, multi-dependency nature of this development environment.

## Example Request

The end goal is that there are no errors and preferably no warnings. The following errors are from the in docker container supercronic cron job or from the docker system calling the healtcheck. `...` is surfacing when /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/healthcheck-nix-sidecar.sh is running. let's make sure that it's dropping permissions to $USERNAME preferably the id instead of the explicit name $PUID both set from the compose file which in turn grabs it from the .env, and then the running account is dropped asap. reference /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/assets/static/nix-sidecar/entrypoint-nix-sidecar.sh and /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base/nix-sidecar/Dockerfile.nix-sidecar to see how everything is created. to make the project do the following command

- cd /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet ; then just base-up this uses the proper order of operations to prepare the environment. DO NOT run docker-compose directly inside of the /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/services/base directory!!!
