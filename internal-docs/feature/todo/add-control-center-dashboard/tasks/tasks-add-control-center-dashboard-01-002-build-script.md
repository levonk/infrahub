---
story_id: "01-002"
story_title: "Create build script for control-center image"
story_name: "build-script"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 1
parallel_id: 2
branch: "feature/current/add-control-center-dashboard/story-01-002-build-script"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["scripts", "justfile"]
priority: "MUST"
risk_level: "low"
tags: ["docker", "build", "justfile", "scripts"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Create `scripts/build-control-center-image.sh` following the directory-empire pattern. Clones lrepo52/control-center, builds multi-stage Docker image (linux/amd64), pushes to local registry.

## Current State

- `scripts/build-directory-empire-image.sh` — reference build script pattern (clone, build, push, --check mode, FORCE_REBUILD)
- `justfile` — contains `build-directory-empire-image` and `build_directory_empire_image_impl` recipes as reference
- No control-center build script exists yet
- Fork patches already pushed (commit a9ba46c on lrepo52/control-center): proxy.ts host allowlist, standalone output, Dockerfile, .dockerignore

## Scope

- Create `scripts/build-control-center-image.sh` following the directory-empire pattern
- Add justfile recipes: `build-control-center-image` and `build_control_center_image_impl`
- Script supports `--check` mode (context hash comparison) and `FORCE_REBUILD`

## Sub-Tasks

- [ ] Read `scripts/build-directory-empire-image.sh` as the reference pattern
- [ ] Create `scripts/build-control-center-image.sh` with: REGISTRY=100.90.22.85:5000, IMAGE_NAME=localnet-dashboard-control-center, REPO_URL=git@github-5:lrepo52/control-center.git, REPO_BRANCH=main, PLATFORMS=linux/amd64
- [ ] Include `--check` mode (context hash comparison) and `FORCE_REBUILD` support
- [ ] Add justfile recipes: `build-control-center-image` and `build_control_center_image_impl` (following the directory-empire pattern in justfile)
- [ ] Make script executable (`chmod +x`)

## Relevant Files

- `scripts/build-directory-empire-image.sh` — reference pattern
- `scripts/build-control-center-image.sh` — new build script
- `justfile` — add recipes

## Acceptance Criteria

- Given the script, When `ls -la scripts/build-control-center-image.sh`, Then it exists and is executable
- Given the script, When run with `--check`, Then it exits 0 (up to date) or 1 (needs rebuild), never 127 (not found)
- Given the justfile, When `just build-control-center-image --check` runs, Then the recipe invokes the script correctly
- Given the script, When `FORCE_REBUILD=1` is set, Then it rebuilds regardless of hash match
- Verify: `bash scripts/build-control-center-image.sh --check` exits 0 or 1 (not 127)

## Test Plan

- `bash scripts/build-control-center-image.sh --check` exits 0 or 1 (not 127)
- `just build-control-center-image --check` runs without recipe errors
- `shellcheck scripts/build-control-center-image.sh` passes (if available)

## Observability

- Script prints context hash on build and check
- Script prints image digest on successful push
- `--check` mode reports whether rebuild is needed

## Compliance

- Multi-stage Docker build (builder + runtime) per AGENTS.md Invariant #2
- Image built on Mac, pushed to registry, pulled on target (never build on target)
- linux/amd64 platform only (target is Windows Docker Desktop)

## Risks & Mitigations

- **Fork Dockerfile build fails**: STOP and report (per PRD STOP conditions)
- **Local registry unreachable**: STOP and report (per PRD STOP conditions)
- **Git clone fails (SSH key)**: Verify github-5 SSH alias is configured in ~/.ssh/config

## Dependencies & Sequencing

- **Dependencies**: None (fork patches already pushed)
- **Dependants**: 03-001 (playbooks need the image to exist for deploy)
- **Parallel-safe**: true (can run alongside 01-001)

## Definition of Done

- Script exists, is executable, justfile recipe works
- `--check` mode returns correct exit codes
- `FORCE_REBUILD` support present

## STOP Conditions

- Fork Dockerfile build fails
- Local registry (100.90.22.85:5000) is unreachable
- Git clone of lrepo52/control-center fails

## Maintenance Notes

- To rebuild after fork updates: `just build-control-center-image`
- To force rebuild: `FORCE_REBUILD=1 just build-control-center-image`
- Script uses context hash to skip unnecessary rebuilds

## Commit Conventions

- Commit subject: `feat(scripts): add control-center image build script`
- Body: describe script, justfile recipes added

## Changelog

- 2026-08-30: Story created
