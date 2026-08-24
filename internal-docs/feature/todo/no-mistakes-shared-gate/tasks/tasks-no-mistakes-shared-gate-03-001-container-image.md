---
story_id: "03-001"
story_title: "Container image Dockerfile + build pipeline"
story_name: "container-image"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 3
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-03-001-container-image"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["container", "docker"]
priority: "MUST"
risk_level: "medium"
tags: ["container", "build", "docker"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Create the multi-stage Dockerfile for the no-mistakes shared gate container and register it in the build pipeline. The image includes no-mistakes (built from Go source), OpenSSH server, git, devin-cli, acpx, and gh CLI.

## Sub-Tasks

- [ ] Create directory `shared/active/03-container/services/devops/no-mistakes/docker/`
- [ ] Create `shared/active/03-container/services/devops/no-mistakes/docker/Dockerfile.no-mistakes`:
  - **Stage 1 (build)**: `golang:1.23-alpine` — build no-mistakes from source via `go install github.com/kunchenguid/no-mistakes/cmd/no-mistakes@latest`
  - **Stage 2 (runtime)**: `alpine:3.20` — install openssh, git, git-shell, gh CLI, ca-certificates
  - Create `gate` user with home `/home/gate`
  - Set `NM_HOME=/home/gate/.no-mistakes`
  - Copy no-mistakes binary from build stage
  - Install devin-cli and acpx (download release binaries)
  - Create git-shell-commands directory with auto-provision wrapper script
  - Configure sshd (port 2222, key-only auth, git-shell for gate user)
  - Entrypoint script: start sshd + no-mistakes daemon
- [ ] Create `shared/active/03-container/services/devops/no-mistakes/docker/entrypoint.sh`:
  - Generate SSH host keys if not present
  - Start sshd in foreground
  - Start no-mistakes daemon (`no-mistakes daemon start`)
  - Wait for both processes
- [ ] Create `shared/active/03-container/services/devops/no-mistakes/docker/git-shell-commands/no-mistakes-gate`:
  - Auto-provision wrapper (parse repo path, compute gate ID, clone+init if needed, forward to gate)
- [ ] Create `shared/active/03-container/services/devops/no-mistakes/docker/config.yaml.j2`:
  - no-mistakes global config template (agent: acp:devin, acpx_path, acp_registry_overrides)
- [ ] Create `shared/active/03-container/services/devops/no-mistakes/README.md`
- [ ] Add entry to `scripts/build-and-push-images.sh`:
  - `"localnet-devops-no-mistakes|docker/Dockerfile.no-mistakes|devops/no-mistakes"`
- [ ] Create reference `docker-compose.no-mistakes.yml` (not used for deployment, just reference)

## Relevant Files

- `shared/active/03-container/services/devops/no-mistakes/docker/Dockerfile.no-mistakes` — Multi-stage build
- `shared/active/03-container/services/devops/no-mistakes/docker/entrypoint.sh` — Container entrypoint
- `shared/active/03-container/services/devops/no-mistakes/docker/git-shell-commands/no-mistakes-gate` — Auto-provision wrapper
- `shared/active/03-container/services/devops/no-mistakes/docker/config.yaml.j2` — no-mistakes config template
- `shared/active/03-container/services/devops/no-mistakes/README.md` — Service documentation
- `scripts/build-and-push-images.sh` — Build pipeline registration
- `shared/active/03-container/services/devops/no-mistakes/docker-compose.no-mistakes.yml` — Reference compose

## Acceptance Criteria

- Given the Dockerfile, When built with `docker build`, Then the image contains no-mistakes, sshd, git, gh, devin, acpx
- Given the build pipeline, When `devbox run -- just docker-build-push localnet-devops-no-mistakes` runs, Then the image builds and pushes to the local registry
- Given the entrypoint, When the container starts, Then sshd and no-mistakes daemon both start
- Given the auto-provision wrapper, When a push arrives for a new repo, Then the gate is created via clone + init

## Test Plan

- `docker build` succeeds locally
- `docker manifest inspect 100.90.22.85:5000/localnet-devops-no-mistakes:latest` returns valid manifest after push
- Container starts and sshd is reachable on port 2222

## Definition of Done

Dockerfile builds, image pushes to registry, build pipeline entry added, entrypoint and auto-provision wrapper created.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 3 (3a Dockerfile, 3b Build Pipeline, 3c Build and Push).
Also see `container-image-build` skill for multi-arch and buildx guidance.

## Key Design Notes

- **Multi-stage build mandatory** (Invariant #2): Go build deps in stage 1, runtime in stage 2
- **X86 only**: dtop202311 is Windows Docker Desktop (X86). No arm64 needed.
- **devin-cli**: Download the latest release binary for linux-amd64 from the Devin CLI releases
- **acpx**: Download from npm or GitHub releases (check acpx availability)
- **git-shell**: The auto-provision wrapper runs as the gate user's login shell, intercepting git-receive-pack
- **NM_HOME**: Set to `/home/gate/.no-mistakes` (mounted as a volume for persistence)
