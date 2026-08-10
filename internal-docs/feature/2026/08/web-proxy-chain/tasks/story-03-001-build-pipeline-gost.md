---
story: "03-001"
title: "Build pipeline for Gost image"
status: "[ ] Todo"
phase: 3
depends_on: ["01-001"]
branch: "feature/current/web-proxy-chain/story-03-001-build-pipeline-gost"
---

# Story 03-001: Build Pipeline for Gost Image

## Goal

Register the Gost image in the build pipeline so it gets built and pushed to
the local registry. MITM, Privoxy, and Varnish use upstream images and don't
need building.

## Files to modify

1. `shared/active/03-container/services/proxy/gost/` — already has Dockerfile.gost
2. `scripts/build-and-push-images.sh` (or equivalent build script) — add Gost
3. Check if a `just` recipe exists for building proxy images

## Context

The Gost Dockerfile already exists at:
`shared/active/03-container/services/proxy/gost/docker/Dockerfile.gost`

It uses `localnet-base-alpine:latest` as the base image and installs
Gost 3.0.0-rc8. The image needs to be:
1. Built as `localnet-proxy-gost:latest`
2. Pushed to the local registry (if one is running)
3. Available on both Windows and OCI hosts

## Acceptance criteria

- [ ] Gost registered in build script
- [ ] Image builds successfully: `docker build -t localnet-proxy-gost:latest -f shared/active/03-container/services/proxy/gost/docker/Dockerfile.gost shared/active/03-container/services/proxy/gost/`
- [ ] `just ansible-syntax` passes
