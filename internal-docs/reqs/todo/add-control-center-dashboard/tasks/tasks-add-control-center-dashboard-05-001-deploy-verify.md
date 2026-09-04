---
story_id: "05-001"
story_title: "Build image, deploy to dtop202311, verify both domains"
story_name: "deploy-verify"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 5
parallel_id: 1
branch: "feature/current/add-control-center-dashboard/story-05-001-deploy-verify"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["04-001"]
parallel_safe: false
modules: []
priority: "MUST"
risk_level: "medium"
tags: ["deploy", "verify", "docker", "healthcheck", "authelia"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Build the Docker image, deploy to dtop202311 via Ansible, verify container health and both domains.

## Current State

- All prerequisite stories (01-001 through 04-001) are complete
- All validation gates pass (ansible-syntax, ansible-lint, check mode, project-lint)
- Build script exists and is executable
- Ansible role, Traefik templates, DNS entries, playbooks, and just recipes are in place
- Local registry (100.90.22.85:5000) is accessible
- Traefik Windows proxy and Authelia are deployed on dtop202311

## Scope

- Build the Docker image and push to local registry
- Deploy to dtop202311 via Ansible
- Verify container health on both domains
- Verify Authelia SSO gate is active
- Run validate playbook

## Sub-Tasks

- [ ] Build image: `just build-control-center-image`
- [ ] Deploy: `just ansible-deploy-control-center`
- [ ] Verify container running: docker ps on dtop202311 shows healthy container
- [ ] Verify health endpoint: `curl -sf https://dashboard.levonk.com/api/health` returns status: ready
- [ ] Verify nl domain: `curl -sf https://dashboard.nl.levonk.com/api/health` returns status: ready
- [ ] Verify no restart loop: check restart count
- [ ] Verify Authelia gate: unauthenticated request redirects to Authelia login
- [ ] Run validate playbook: `just ansible-validate-control-center`

## Relevant Files

- `justfile` — build, deploy, validate recipes
- `scripts/build-control-center-image.sh` — build script
- `shared/active/02-config/ansible/playbooks/deploy-control-center.yml` — deploy playbook
- `shared/active/02-config/ansible/playbooks/validate-control-center.yml` — validate playbook

## Acceptance Criteria

- Given the build script, When `just build-control-center-image` runs, Then the image is pushed to the local registry
- Given the deploy playbook, When `just ansible-deploy-control-center` runs, Then the container is running on dtop202311
- Given the container, When checking `docker ps`, Then it shows a healthy container with no restart loops
- Given dashboard.levonk.com, When `curl -sf https://dashboard.levonk.com/api/health`, Then it returns 200 with status: ready
- Given dashboard.nl.levonk.com, When `curl -sf https://dashboard.nl.levonk.com/api/health`, Then it returns 200 with status: ready
- Given an unauthenticated request, When curling either domain, Then it redirects to Authelia login
- Given the validate playbook, When `just ansible-validate-control-center` runs, Then all checks pass
- Verify: curl to /api/health on both domains returns 200 with status: ready

## Test Plan

- `just build-control-center-image` pushes image to registry
- `just ansible-deploy-control-center` deploys without errors
- `docker ps` on dtop202311 shows healthy container
- `curl -sf https://dashboard.levonk.com/api/health` returns 200 with status: ready
- `curl -sf https://dashboard.nl.levonk.com/api/health` returns 200 with status: ready
- Unauthenticated request to either domain redirects to Authelia login
- `just ansible-validate-control-center` passes all checks
- Container restart count is 0 (no restart loops)

## Observability

- Health endpoint: GET /api/health returns {service, status, version}
- Container healthcheck: curl -sf /api/health (503 if DB unhealthy)
- Container restart_policy: unless-stopped
- Traefik dashboard shows both routers
- Authelia logs show authentication events

## Compliance

- Container uptime target > 99% after deployment
- Health check responds < 500ms
- No restart loops
- Authelia SSO gate active before app's own auth

## Risks & Mitigations

- **Image build fails**: STOP (per PRD STOP conditions)
- **Container restart loop**: Check logs, verify volume mount, verify env vars
- **Health endpoint returns 503**: DB may be unhealthy; check SQLite volume
- **Domain not reachable**: Verify DNS propagation, Traefik config, Authelia middleware
- **Authelia gate not active**: Verify middleware chain in Traefik dynamic config

## Dependencies & Sequencing

- **Dependencies**: 04-001 (all validation gates must pass)
- **Dependants**: None (this is the final story)
- **Parallel-safe**: false (deployment is a sequential operation)

## Definition of Done

- Container healthy on dtop202311
- Both domains respond with status: ready
- Authelia gate active (unauthenticated requests redirect to login)
- No restart loops
- Validate playbook passes all checks

## STOP Conditions

- Image build fails
- Container enters restart loop
- Health endpoint returns 503 after multiple retries
- Domains not reachable after DNS propagation wait
- Authelia gate not active

## Maintenance Notes

- Image rebuild: run `just build-control-center-image` after fork updates, then redeploy
- Data backup: rsync the SQLite volume to backup location (documented in role README)
- First user registration: visit /register after Authelia auth to create the first tenant
- Container uptime monitoring: check `docker ps` and health endpoint periodically

## Commit Conventions

- Commit subject: `feat(deploy): deploy control-center to dtop202311 and verify`
- Body: document deployment results, health checks, domain verification

## Changelog

- 2026-08-30: Story created
