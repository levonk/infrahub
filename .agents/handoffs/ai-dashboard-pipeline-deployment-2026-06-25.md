# AI Dashboard Pipeline Deployment Handoff

**Date**: 2026-06-25  
**Session**: Network configuration fix and pipeline deployment  
**Status**: Network fixed, deployment blocked by build/auth issues

## Current State

### ✅ Completed
- **Network Configuration Fixed**: 
  - Recreated `proxy-chain-network` with correct subnet `172.29.0.0/16`
  - Reconnected `headroom` to `172.29.0.13` (healthy)
  - Reconnected `iron-proxy` to `172.29.0.17` (running but unhealthy)
- **Configuration Files Updated**:
  - `docker-compose.ai-dashboard-pipeline.yml` - Added proxy configuration
  - `docker-compose.ai.yml` - Added proxy-chain-network and proxy env vars
  - `docker-compose.iron-proxy.yml` - Added proxy-chain-network and fixed health check
  - `.env.pipeline` - Fixed iron-proxy URL and added upstream proxy config
  - `deploy-ai-dashboard-pipeline.yml` - Network reconnection steps

### ❌ Blocking Issues
1. **OmniRoute Build Failed**: Missing Docker context for omniroute build
2. **Iron-Proxy Image Pull**: GHCR authentication denied for `ghcr.io/ironsh/iron-proxy:latest`
3. **Ansible Playbook Syntax Error**: Conflicting `ansible.builtin.shell` with `chdir` statements

## Target Pipeline Architecture

```
AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
        (Entry)              (PII Detection) (Compression)   (Routing)       (Tool Calling Fixer)    (Pre-Egress)    (Security)    (Privacy)
```

## Network Configuration

**proxy-chain-network**: `172.29.0.0/16` (gateway: `172.29.0.1`)
- `headroom`: `172.29.0.13:8787` ✅ healthy
- `omniroute`: `172.29.0.14:20128` ❌ not deployed
- `forge`: `172.29.0.16:8081` ❌ not deployed  
- `iron-proxy`: `172.29.0.17:80,443` ⚠️ running but unhealthy

## Required Tasks

### 1. Fix OmniRoute Build Issue
**Problem**: Docker compose build failed with missing context
```bash
docker compose -f docker-compose.ai.yml --profile all up omniroute -d --force-recreate
# Error: build context missing
```

**Investigation Needed**:
- Check if omniroute Dockerfile exists at `./omniroute/docker/Dockerfile.omniroute`
- Verify build context path in `docker-compose.ai.yml`
- Consider using pre-built image if build context is unavailable

**Files to Check**:
- `~/p/gh/levonk/infrahub/shared/active/03-container/services/ai-services/docker-compose.ai.yml`
- Omniroute Dockerfile location

### 2. Fix Iron-Proxy Image Issue  
**Problem**: GHCR authentication denied
```bash
# Error: Head "https://ghcr.io/v2/ironsh/iron-proxy/manifests/latest": denied
```

**Solutions to Try**:
- Check if Docker Hub has alternative image: `ironsh/iron-proxy:latest`
- Use local build if Dockerfile available
- Check GHCR authentication requirements
- Consider alternative egress proxy solutions

**Current Configuration**:
- Image: `ghcr.io/ironsh/iron-proxy:latest`
- Container name: `localnet-proxy-iron-proxy`
- Health check: `wget --spider -q http://localhost:80/health`

### 3. Fix Ansible Playbook Syntax Error
**Problem**: Conflicting action statements with `chdir`
```
[ERROR]: conflicting action statements: ansible.builtin.shell, chdir
Origin: deploy-ai-dashboard-pipeline.yml:183:7
```

**Root Cause**: Multiple shell tasks with `chdir` in same task block
**Fix Required**: Reorganize tasks to avoid conflicting statements

**File to Fix**:
- `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml`

### 4. Deploy Full Pipeline
**After fixes 1-3**, deploy the complete pipeline:
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

### 5. Test and Validate
**Health Checks**:
```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check specific services
docker inspect headroom --format='{{.State.Health.Status}}'
docker inspect omniroute --format='{{.State.Health.Status}}'
docker inspect iron-proxy --format='{{.State.Health.Status}}'
```

**Network Connectivity**:
```bash
# Test headroom → omniroute
docker exec headroom wget -O- http://omniroute:20128/v1/models

# Test omniroute → iron-proxy  
docker exec omniroute wget -O- http://iron-proxy:80/health
```

**Log Validation**:
```bash
# Check for errors
docker logs headroom --tail=50 | grep -i error
docker logs omniroute --tail=50 | grep -i error
docker logs iron-proxy --tail=50 | grep -i error
docker logs forge --tail=50 | grep -i error
```

## Dashboard URLs (Post-Deployment)

**AI Dashboard**: `https://ai-dashboard.levonk.com`
- Protected by: GeoBlock (US-only), CrowdSec Bouncer, Authelia SSO with 2FA
- SSL: Let's Encrypt via Traefik

**OmniRoute Dashboard**: `https://ai-gateway.levonk.com`  
- Protected by: GeoBlock (US-only), CrowdSec Bouncer, Authelia SSO with 2FA
- SSL: Let's Encrypt via Traefik

## Important Notes

- **Network Subnet**: Must be `172.29.0.0/16` (not `192.168.117.0/24`)
- **Iron-Proxy Health Check**: Should use port 80, not 8080
- **Proxy Configuration**: All services should route through iron-proxy for egress
- **Headroom Upstream**: Should point to omniroute, not direct to AI providers
- **OmniRoute Compression**: Must be disabled (Headroom handles compression)

## Files Modified This Session

1. `shared/active/03-container/services/ai-dashboard/docker-compose.ai-dashboard-pipeline.yml`
2. `shared/active/03-container/services/ai-dashboard/.env.pipeline`
3. `shared/active/03-container/services/ai-services/docker-compose.ai.yml`
4. `shared/active/03-container/services/proxy/iron-proxy/docker-compose.iron-proxy.yml`
5. `shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml`

## Success Criteria

- ✅ All pipeline containers running and healthy
- ✅ Network connectivity: headroom → omniroute → iron-proxy
- ✅ No errors in container logs
- ✅ Health checks passing for all services
- ✅ Dashboard URLs accessible via HTTPS with auth
- ✅ Pipeline flow matches architecture diagram

## Additional Context

- **Project**: infrahub (Docker Compose-based deployment)
- **Client**: levonk (git submodule at `~/p/gh/levonk/infrahub/levonk`)
- **ADR Compliance**: Follow ADR-20260624001 for secret storage
- **Shell Commands**: Use `devbox run --` for all commands
- **Git Workflow**: Commit changes after successful deployment
