# LocalNet Development Environment - Agent Instructions

If you're working on Nix containers, see the documetnation at:

- /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet/internal-docs/requirements/nix/

## 🚀 Environment Setup

This project uses **Devbox** for environment management. Follow these steps:

### 1. Setup Devbox Environment
```bash
# Ensure you're in the correct directory
cd apps/active/devops/localnet

# Start devbox shell (installs just, yq-go, jq)
devbox shell

# Or run commands directly through devbox
devbox run -- just base-up-internal
```

### 2. Available Commands
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

# Direct devbox commands (bypass just)
devbox run -- just base-up-internal
devbox run -- just up-internal
devbox run -- just down-internal
devbox run -- just clean-internal
devbox run -- just logs-internal
devbox run -- just health-check-internal
devbox run -- just test-internal
devbox run -- just bootstrap-internal

# Direct just-internal targets (bypass devbox)
just base-up-internal
just up-internal
just down-internal
just build-internal
just clean-internal
just logs-internal
just health-check-internal
just test-internal
just bootstrap-internal
```

### 3. ADR Compliance Notes
This justfile includes `-internal` recipe variants to comply with ADR-20260131001:
- All main recipes have corresponding `-internal` variants
- `-internal` recipes delegate to their main counterparts
- Enables parent devbox.json to call `bootstrap-internal` and other `-internal` targets

### 4. Why Devbox?
- Provides consistent development environment
- Includes required tools (just, yq-go, jq)
- Ensures proper package versions
- Follows monorepo standards from ADR-20260131001

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

## ⚠️ IMPORTANT: Always Use the Justfile

**NEVER start services directly with `docker-compose up` or `docker-compose start`.** Always use the justfile targets:

```bash
# Start all services
just up

# Start specific service group
just base-up
just up-dns
just up-artifact

# Stop all services
just down

# Restart services
just restart
```

## Why the Justfile is Required

### 1. Environment File Loading

The justfile ensures proper loading of environment files in the correct order:

- `env.template` - Base environment variables
- `env.local` - Local overrides (if exists)
- Service-specific env files for proper configuration

### 2. Docker Compose File Ordering

Services must be started in a specific dependency order:

1. **Base services** (nix-sidecar, etc.) - Foundation services
2. **DNS services** (CoreDNS, DNSDist, dnscrypt-proxy) - Network layer
3. **Artifact services** (Harmonia, NCPS) - Application layer

Starting services out of order will cause dependency failures.

### 3. Network and Volume Initialization

The justfile handles:

- Creating Docker networks in the correct sequence
- Initializing shared volumes
- Setting up proper inter-service communication

### 4. Environment Variable Substitution

Many services use environment variables in their configurations:

- Port mappings (e.g., `DNS_TRANSPARENT_HOST_PORT`)
- IP addresses for service communication
- Feature flags and debug settings

The justfile ensures these are properly exported before Docker Compose runs.

## Service Groups

### Base Services (`just up-base`)

- `nix-sidecar` - Nix package manager and caching
- Foundation services that other containers depend on

### DNS Services (`just up-dns`)

- `coredns` - Local DNS resolver
- `dnsdist` - DNS router/forwarder
- `dnscrypt-proxy-*` - Encrypted DNS clients
- Must start after base services

### Artifact Services (`just up-artifact`)

- `harmonia` - Nix cache server
- `ncps` - Nix binary cache proxy
- Must start after DNS services

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
