# NX Build Orchestration

**Phase**: 8.6  
**Status**: In Progress  
**Last Updated**: 2025-01-21

## Overview

This document describes the NX monorepo integration for build orchestration in LocalNet. NX provides intelligent caching, dependency graphs, and optimized build pipelines that solve the "rebuilding unrelated projects" problem inherent in Docker Compose.

## Problem Statement

### Before NX (Docker Compose Only)
- **Parallel builds without dependency awareness**: Docker Compose builds all services in a profile simultaneously
- **No caching between unrelated changes**: Changing a comment in one service triggers rebuilds of all dependent services
- **Manual orchestration**: The justfile uses sequential profile execution (base01 → base02 → base03) to enforce build order
- **Wasted time**: 30+ minute builds for changes that should take seconds

### After NX (Smart Build Orchestration)
- **Dependency graph**: NX builds services in the correct order based on `implicitDependencies`
- **Intelligent caching**: Only rebuilds what actually changed, using content hashing
- **Parallelization**: Builds independent services in parallel (configurable)
- **Affected builds**: Build only services affected by current changes

## Architecture

### Dependency Graph

```
┌─────────────────────────────────────────────────────────────┐
│                    DEPENDENCY TREE                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Level 1: Foundation                                         │
│  ├── localnet-base-alpine                                   │
│  ├── localnet-base-debian                                   │
│  └── localnet-base-kali                                     │
│         │                                                    │
│  Level 2: Nix + Sidecars                                     │
│  └── localnet-nix-sidecar ◄── depends on alpine              │
│         │                                                    │
│  Level 3: Base Variants                                      │
│  ├── localnet-base-nix ◄───── depends on nix-sidecar       │
│  ├── localnet-base-kalinix ◄─ depends on kali + nix-sidecar  │
│  └── localnet-base-sidecar ◄─ depends on base-nix           │
│         │                                                    │
│  Level 4: Tool Sidecars                                      │
│  ├── localnet-pnpm-sidecar ◄─ depends on base-sidecar      │
│  ├── localnet-nx-sidecar ◄─── depends on base-sidecar       │
│  │      + implicit: pnpm-sidecar                           │
│  └── ...                                                     │
│         │                                                    │
│  Level 5: Services                                           │
│  ├── localnet-artifact-nexus                               │
│  ├── localnet-artifact-verdaccio ◄─ depends on pnpm-sidecar │
│  └── ...                                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `nx.json` | Core NX configuration, caching rules, task pipeline |
| `package.json` | Node dependencies, NX plugins, npm scripts |
| `*/project.json` | Per-service build configuration and dependencies |

## Quick Start

### 1. Install Dependencies

```bash
cd apps/active/devops/localnet
just nx-install
```

### 2. Build with NX

```bash
# Build base images (foundation layer)
just nx-build-base

# Build sidecars
just nx-build-sidecars

# Build everything with optimal caching
just nx-build

# Build only affected services (since last commit)
nx affected -t docker:build
```

### 3. Visualize Dependencies

```bash
just nx-graph
```

## Available Commands

### NX Build Commands (via justfile)

| Command | Description |
|---------|-------------|
| `just nx-install` | Install NX dependencies (pnpm install) |
| `just nx-build-base` | Build foundation images (alpine, debian, kali) |
| `just nx-build-sidecars` | Build sidecar containers |
| `just nx-build` | Build all services with smart caching |
| `just nx-affected` | Build only services changed since last commit |
| `just nx-graph` | Open dependency graph visualization |
| `just nx-clear-cache` | Clear NX and Docker build cache |

### Hybrid Commands (NX Build + Compose Deploy)

| Command | Description |
|---------|-------------|
| `just nx-up-base` | Build base images with NX, start with Compose |
| `just nx-up-artifacts` | Build sidecars with NX, start artifact services |

### Direct NX Commands

```bash
# Build specific service
nx docker:build localnet-base-alpine

# Build all base images
nx run-many -t docker:build --projects=tag:base

# Build with parallelization (4 concurrent)
nx run-many -t docker:build --all --parallel=4

# Check dependency graph (CLI)
nx graph --file=dep-graph.json
```

## Configuration

### Service Tags

Services are categorized using tags for group builds:

| Tag | Description |
|-----|-------------|
| `base` | Foundation images (alpine, debian, kali, nix) |
| `sidecar` | Shared volume sidecars (nix, pnpm, nx, rust, etc.) |
| `service` | Application services (nexus, verdaccio, etc.) |
| `artifact` | Artifact-related services |
| `foundation` | Critical infrastructure (base images, nix-sidecar) |
| `cache` | Cache services (nx-sidecar, turbo-cache) |

### Caching Configuration

NX caches builds based on:

1. **Input files**: Dockerfile, assets, scripts
2. **Dependencies**: Changes to parent images invalidate child caches
3. **Environment**: `.env.local.localnet` changes trigger rebuilds

```json
// nx.json
{
  "targetDefaults": {
    "docker:build": {
      "inputs": [
        "{projectRoot}/Dockerfile*",
        "{projectRoot}/assets/**/*",
        "{projectRoot}/**/*.sh",
        "{workspaceRoot}/docker-compose.shared.yml"
      ],
      "cache": true
    }
  }
}
```

### Dependency Declaration

Services declare dependencies via `implicitDependencies`:

```json
// services/artifact/pnpm-sidecar/project.json
{
  "name": "localnet-pnpm-sidecar",
  "implicitDependencies": ["localnet-base-sidecar"],
  "tags": ["sidecar", "artifact"]
}
```

## Migration Guide

### From Docker Compose Profiles

| Old (Docker Compose) | New (NX) |
|---------------------|----------|
| `just base-up` | `just nx-build-base` |
| `just up-core-nix` | `just nx-build-sidecars` |
| `just build` | `just nx-build` |
| Profile sequencing | Automatic dependency resolution |
| Manual parallelization | `--parallel=N` flag |

### Hybrid Workflow (Recommended)

For daily use, combine NX and Docker Compose:

```bash
# 1. Build with NX (cached, optimized)
just nx-build

# 2. Deploy with Compose (proven, flexible)
just up-localnet
```

## Performance Comparison

### Scenario: Change to `services/base/alpine/Dockerfile`

| Step | Docker Compose | NX |
|------|----------------|-----|
| Detect changes | Manual | Automatic |
| Build alpine | ✅ Yes | ✅ Yes |
| Build nix-sidecar | ✅ Yes | ✅ Yes (dependent) |
| Build base-nix | ✅ Yes | ✅ Yes (dependent) |
| Build base-sidecar | ✅ Yes | ✅ Yes (dependent) |
| Build pnpm-sidecar | ✅ Yes | ✅ Yes (dependent) |
| Build nexus | ❌ Unnecessary | ✅ Not rebuilt |
| Build verdaccio | ❌ Unnecessary | ✅ Not rebuilt |
| **Total Time** | ~15 min | ~5 min |

### Scenario: Change to `services/artifact/nexus/Dockerfile`

| Step | Docker Compose | NX |
|------|----------------|-----|
| Detect changes | Manual | Automatic |
| Rebuild base images | ❌ Unnecessary (but happens) | ✅ Skipped (cache hit) |
| Rebuild nexus | ✅ Yes | ✅ Yes |
| **Total Time** | ~20 min | ~2 min |

## Troubleshooting

### NX Not Found

```bash
# Install NX CLI globally (optional but convenient)
pnpm add -g nx

# Or use via pnpm
pnpm exec nx <command>
```

### Cache Issues

```bash
# Clear NX cache
just nx-clear-cache

# Or manually
rm -rf .nx/cache

# Verify cache after rebuild
ls -la .nx/cache
```

### Dependency Graph Errors

```bash
# Validate configuration
nx validate

# Check project configuration
nx show project localnet-base-alpine --json
```

## Future Enhancements

### Phase 8.7: Justfile Integration
- Make NX the default build system
- Add `--use-nx` flag to existing commands
- Maintain backward compatibility

### Phase 8.8: Remote Caching
- Configure Nx Cloud or self-hosted cache
- Share build cache across team machines
- CI/CD integration

### Phase 8.9: Ansible Integration
- Ansible playbooks for environment-specific deployment
- Inventory management for Mac/Windows/HomeLab/Cloud
- Dynamic inventory from NX project graph

## References

- [NX Documentation](https://nx.dev/getting-started/intro)
- [@nx-tools/nx-container](https://github.com/nx-tools/nx-container)
- [Docker BuildKit](https://docs.docker.com/build/buildkit/)
- LocalNet AGENTS.md
