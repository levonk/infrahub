# Vibe Kanban & Agents Smoke Test Guide

This document outlines the procedure to verify the correct deployment and integration of Vibe Kanban, Opencode, and Auto-Claude agents within the `ai-codeassist` stack.

## Prerequisites

- Localnet stack is running (`docker compose up -d` or equivalent).
- `kanban.levonk.com` resolves to the Traefik load balancer IP (e.g., via `/etc/hosts` or local DNS).
- Required environment variables are set in `.env` (check `env.template` for `KANBAN_SESSION_SECRET`, tokens, etc.).

## 1. Service Health Checks

Verify that all agent containers are up and healthy.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}" | grep -E 'vibe-kanban|opencode|autoclaude'
```

**Expected Output:**
- `vibe-kanban`: Up, (healthy)
- `opencode-runner`: Up, (healthy)
- `autoclaude-runner`: Up, (healthy)

## 2. Vibe Kanban UI Access

1. Open `https://kanban.levonk.com` in your browser.
2. You should be redirected to the Authelia login page (if not already authenticated).
3. Authenticate with your Authelia credentials.
4. Verify the Vibe Kanban interface loads.

## 3. Docker Access Verification (Platform Specific)

Verify that the containers have the correct access to the Docker daemon (either via Sysbox/DIND or Dockerproxy).

**Linux (Sysbox + DIND):**
```bash
docker exec -it vibe-kanban docker ps
```
*Should list containers running *inside* the DIND sidecar (likely empty initially), or show the DIND daemon info.*

**WSL2 (Dockerproxy):**
```bash
docker exec -it vibe-kanban curl --unix-socket /var/run/docker.sock http://localhost/containers/json
```
*Should return a JSON list of containers from the host (filtered by proxy rules).*

## 4. Agent API Connectivity (Shim Check)

Test the health endpoints of the agent runners directly (internal check).

**Auto-Claude Shim:**
```bash
docker exec -it autoclaude-runner curl -f http://localhost:8080/healthz
```
*Expected: `{"status":"ok", ...}`*

**Opencode Shim:**
```bash
docker exec -it opencode-runner curl -f http://localhost:8000/healthz
```
*Expected: `{"status":"ok", ...}`*

## 5. End-to-End Session Launch (Manual Trigger)

Since the UI integration might still be in progress, verify you can trigger a session via the shim API.

**Start Auto-Claude Session:**
```bash
curl -X POST http://localhost:8080/sessions/start \
  -H "Content-Type: application/json" \
  -d '{"repo_path": "/p/gh/lrepo52/job-aide"}'
```
*(Note: Run this from inside a container on the `localnet` network if localhost isn't mapped, or map port 8080 temporarily).*

## 6. Troubleshooting

- **Logs:**
  ```bash
  docker logs -f vibe-kanban
  docker logs -f opencode-runner
  docker logs -f autoclaude-runner
  ```
- **Traefik Routing:** Check `https://traefik.levonk.com/dashboard/` to verify the `vibe-kanban` router is active and error-free.
- **Permissions:** Ensure the `/p` mount is accessible and writable by the container user (`nodejs` or `app`).
