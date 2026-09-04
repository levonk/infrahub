---
story_id: "03-004-1"
story_title: "Fix critical deployment issues blocking E2E testing"
story_name: "critical-deployment-fixes"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 3
parallel_id: 4
branch: "feature/current/traefik-authelia-cloudflare/story-03-004-1-critical-deployment-fixes"
status: "completed"
assignee: ""
reviewer: ""
dependencies: ["03-001", "03-002", "03-003"]
parallel_safe: false
modules: ["traefik", "authelia", "crowdsec", "docker", "cloudflare"]
priority: "CRITICAL"
risk_level: "high"
tags: ["hotfix", "deployment", "critical", "blocking"]
due: "2026-06-21"
created_at: "2026-06-21"
updated_at: "2026-06-21"
---

## Summary

Fix critical deployment issues discovered during initial E2E testing that are blocking story 03-004 from proceeding. These issues prevent the Traefik proxy stack from functioning correctly and must be resolved before end-to-end testing can continue.

## Critical Issues to Fix

### Issue 1: Docker Socket Permission Error
**Problem**: Traefik cannot access Docker socket (`permission denied while trying to connect to the Docker daemon socket`), preventing Docker provider from discovering containers and services.

**Root Cause**: Traefik container does not have proper permissions to access Docker socket at `/var/run/docker.sock`

**Fix Required**:
- Add Traefik container to docker group or use proper socket binding
- Ensure Docker socket is mounted with correct permissions in docker-compose
- Verify Traefik can discover containers via Docker provider

### Issue 2: Plugin Download Failure
**Problem**: CrowdSec plugin cannot be downloaded - `Unknown plugin: github.com/crowdsecurity/crowdsec-traefik-bouncer@v1.4.4`

**Root Cause**: Plugin version or path is incorrect in Traefik configuration

**Fix Required**:
- Verify correct CrowdSec Traefik bouncer plugin version and path
- Update Traefik configuration with correct plugin reference
- Test plugin download and installation

### Issue 3: Missing Cloudflare Credentials
**Problem**: ACME certificate generation failing - `some credentials information are missing: CLOUDFLARE_EMAIL,CLOUDFLARE_API_KEY`

**Root Cause**: Cloudflare credentials not properly configured in Ansible vault or environment

**Fix Required**:
- Add Cloudflare email and API key to Ansible vault
- Ensure credentials are properly referenced in Traefik ACME configuration
- Test certificate generation with Cloudflare DNS challenge

### Issue 4: ClientIP Rule Syntax Error
**Problem**: Tailscale bypass rule has incorrect syntax - `error while adding rule ClientIP: unexpected number of parameters; got 2, expected one of [1]`

**Root Cause**: ClientIP middleware configuration has incorrect parameter syntax

**Fix Required**:
- Fix ClientIP middleware syntax in Traefik dynamic configuration
- Ensure Tailscale network bypass rule uses correct parameter format
- Test Tailscale bypass functionality

### Issue 5: Middleware Configuration Error
**Problem**: CrowdSec middleware not recognized - `invalid middleware "crowdsec-bouncer@file" configuration: invalid middleware type or middleware does not exist`

**Root Cause**: CrowdSec middleware is not properly defined or loaded in Traefik configuration

**Fix Required**:
- Ensure CrowdSec middleware is properly defined in dynamic configuration
- Verify middleware is loaded before being referenced in router configuration
- Test CrowdSec middleware functionality

### Issue 6: Authelia Network Configuration (RESOLVED)
**Problem**: Authelia was not connected to traefik-network initially

**Status**: Manually fixed during investigation - no action needed

## Sub-Tasks

- [x] Fix Docker socket permissions for Traefik container
- [x] Verify Traefik Docker provider can discover containers
- [x] Fix CrowdSec plugin download configuration
- [x] Add Cloudflare credentials to Ansible vault
- [x] Configure Traefik ACME with Cloudflare DNS challenge
- [x] Fix ClientIP middleware syntax for Tailscale bypass
- [x] Fix CrowdSec middleware configuration
- [x] Test all fixes together to ensure Traefik starts without errors
- [x] Verify all containers are healthy and communicating
- [x] Test basic routing functionality before proceeding to E2E tests

## Relevant Files

- `shared/active/03-container/services/traefik/docker-compose.traefik.yml` - Traefik docker-compose configuration
- `shared/active/03-container/services/traefik/config/traefik.dynamic.yml` - Traefik dynamic configuration
- `shared/active/03-container/services/traefik/config/traefik.yml` - Traefik static configuration
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Host variables
- `shared/active/02-config/ansible/vault/` - Ansible vault for secrets
- `shared/active/02-config/ansible/roles/proxy-traefik/` - Traefik Ansible role

## Acceptance Criteria

- [ ] Traefik can access Docker socket without permission errors
- [ ] Traefik Docker provider successfully discovers all containers
- [ ] CrowdSec plugin downloads and installs correctly
- [ ] Cloudflare credentials are properly stored in vault and referenced
- [ ] ACME certificate generation works with Cloudflare DNS challenge
- [ ] ClientIP middleware syntax is correct and Tailscale bypass works
- [ ] CrowdSec middleware is properly defined and functional
- [ ] Traefik starts without critical errors in logs
- [ ] All proxy stack containers are healthy and communicating
- [ ] Basic routing to services works before E2E testing

## Test Plan

- Start Traefik and verify no permission errors in logs
- Check Traefik dashboard to verify Docker provider is working
- Test plugin download manually if needed
- Verify Cloudflare credentials are accessible from Traefik container
- Test certificate generation with dry-run if possible
- Validate Traefik configuration syntax before applying
- Test Tailscale network access without authentication
- Verify CrowdSec middleware is loaded in Traefik dashboard
- End-to-end ping test through proxy stack

## Observability

- Monitor Traefik logs for permission errors
- Check Docker provider status in Traefik dashboard
- Verify plugin installation status
- Monitor ACME certificate generation logs
- Test middleware chain in Traefik dashboard
- Check container health status

## Compliance

- Ensure Cloudflare credentials are properly secured in Ansible vault
- Follow AGENTS.md guidelines for variable-driven configuration
- No hardcoded credentials in configuration files
- Proper secret management practices

## Risks & Mitigations

- Risk: Docker socket permissions may affect other containers - Mitigation: Test only Traefik container access
- Risk: Plugin version incompatibility - Mitigation: Verify compatible plugin version for Traefik version
- Risk: Cloudflare API rate limits - Mitigation: Use test API calls first
- Risk: Configuration syntax errors - Mitigation: Validate configuration before applying

## Dependencies & Sequencing

- Depends on: Stories 03-001, 03-002, 03-003 (must be complete)
- Unblocks: Story 03-004 (E2E testing and documentation)
- Must complete before: Any end-to-end testing can proceed

## Definition of Done

- All 5 critical issues are resolved
- Traefik starts without critical errors
- All containers are healthy and communicating
- Basic routing functionality works
- Story 03-004 can proceed with acceptance criteria verification

## Commit Conventions

- Use conventional commits: `fix(traefik): resolve Docker socket permission error`
- Scope commits to specific issue fixes
- Reference story ID in commit messages: `Story 03-004-1`
- Use clear commit messages describing the issue and fix

## Notes

This is a hotfix story created to unblock story 03-004. All issues must be resolved before E2E testing can proceed. The fixes should be tested incrementally to avoid introducing new issues.
