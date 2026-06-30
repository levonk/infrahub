#!/usr/bin/env bash
# Build and push all locally-built images to the local Docker registry.
#
# Usage:
#   scripts/build-and-push-images.sh           # build + push all (skips unchanged)
#   scripts/build-and-push-images.sh headroom   # build + push one image
#   scripts/build-and-push-images.sh --list     # list all images
#   scripts/build-and-push-images.sh --force    # force rebuild all (ignore cache)
#   FORCE_REBUILD=1 scripts/build-and-push-images.sh headroom  # force rebuild one
#
# Per AGENTS.md Invariant #2: build on Mac → push to registry → pull on target.
# NEVER build on the target host.
set -euo pipefail

REGISTRY="${REGISTRY:-100.90.22.85:5000}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICES="$ROOT/shared/active/03-container/services"
# Target platform — OCI server is aarch64. Build for that platform.
PLATFORM="${PLATFORM:-linux/arm64}"

# Image name | Dockerfile (relative to context dir) | Context dir (relative to SERVICES)
IMAGES=(
  "localnet-agentmemory|docker/Dockerfile.agentmemory|agentmemory"
  "localnet-dns-adguard|Dockerfile.adguard|dns/adguard"
  "localnet-dns-blocklist-compiler|Dockerfile.blocklist-compiler|dns/dns-blocklists"
  "localnet-dns-coredns|docker/Dockerfile.coredns|dns/coredns"
  "localnet-dns-dnscrypt-plaintext|docker/Dockerfile.dnscrypt-proxy|dns/dnscrypt"
  "localnet-dns-dnsdist|docker/Dockerfile.dnsdist|dns/dnsdist"
  "localnet-proxy-tor|docker/Dockerfile.tor|proxy/tor"
  "localnet-proxy-9router|Dockerfile|proxy/9router"
  "localnet-base-alpine|Dockerfile.base-alpine|base/base-alpine"
  "isolation-vm-base-kali|Dockerfile.base-kali|base/base-kali"
  "isolation-vm-base-kalinix|Dockerfile.base-kalinix|base/base-kalinix"
  "isolation-vm-hermes-agent|Dockerfile.hermes-agent|base/hermes-agent"
  "isolation-vm-nix-sidecar|Dockerfile.nix-sidecar|base/nix-sidecar"
  "localnet-ai-omniroute|docker/Dockerfile.omniroute|ai-services/omniroute"
  "headroom|Dockerfile.headroom|ai-codeassist/headroom"
)

# NOTE: envoy, privoxy, squid use upstream Docker Hub images directly (no custom Dockerfile).
# See roles/forward-proxy/tasks/{envoy,privoxy,squid}.yml for the upstream image references.

list_images() {
  for entry in "${IMAGES[@]}"; do
    IFS='|' read -r name dockerfile context <<< "$entry"
    echo "  $name  ($dockerfile)"
  done
}

build_and_push() {
  local name="$1" dockerfile="$2" context="$3"
  local full_tag="$REGISTRY/$name:latest"
  local ctx_path="$SERVICES/$context"
  local df_path="$SERVICES/$context/$dockerfile"

  if [ ! -f "$df_path" ]; then
    echo "SKIP: $name — Dockerfile not found at $df_path" >&2
    return 0
  fi
  if [ ! -d "$ctx_path" ]; then
    echo "SKIP: $name — context dir not found at $ctx_path" >&2
    return 0
  fi

  # Check if image already exists in registry with same content hash.
  # Compute a hash of the Dockerfile + context to detect changes.
  local ctx_hash
  ctx_hash=$(find "$ctx_path" -type f -exec sha256sum {} + 2>/dev/null | sha256sum | cut -c1-12)
  local label="ctxhash=$ctx_hash"

  # Check if we already pushed this exact hash (via docker label on the registry image)
  local existing_digest
  existing_digest=$(docker manifest inspect "$full_tag" 2>/dev/null | head -1 || true)
  if [ -n "$existing_digest" ] && [ "${FORCE_REBUILD:-0}" != "1" ]; then
    # Image exists in registry. Check if local image has same hash label.
    local local_hash
    local_hash=$(docker inspect "$full_tag" --format '{{index .Config.Labels "ctxhash"}}' 2>/dev/null || true)
    if [ "$local_hash" = "$ctx_hash" ]; then
      echo "CACHED: $name — already built with same context hash ($ctx_hash), skipping"
      return 0
    fi
  fi

  echo "BUILD: $name  ($df_path)  [platform=$PLATFORM, ctxhash=$ctx_hash]"
  docker build --platform "$PLATFORM" --label "$label" -t "$full_tag" -f "$df_path" "$ctx_path"
  echo "PUSH:  $name  → $full_tag"
  docker push "$full_tag"
  echo "DONE:  $name"
  echo
}

main() {
  if [ "${1:-}" = "--list" ]; then
    list_images
    return 0
  fi

  if [ "${1:-}" = "--force" ]; then
    shift
    export FORCE_REBUILD=1
  fi

  if [ $# -gt 0 ] && [ "${1:-}" != "--all" ]; then
    # Build specific image(s)
    for target in "$@"; do
      local found=0
      for entry in "${IMAGES[@]}"; do
        IFS='|' read -r name dockerfile context <<< "$entry"
        if [ "$name" = "$target" ]; then
          build_and_push "$name" "$dockerfile" "$context"
          found=1
          break
        fi
      done
      if [ "$found" -eq 0 ]; then
        echo "ERROR: Unknown image '$target'. Use --list to see available images." >&2
        return 1
      fi
    done
    return 0
  fi

  # Build all
  echo "Building and pushing ${#IMAGES[@]} images to $REGISTRY"
  echo
  local failed=0
  for entry in "${IMAGES[@]}"; do
    IFS='|' read -r name dockerfile context <<< "$entry"
    if ! build_and_push "$name" "$dockerfile" "$context"; then
      failed=$((failed + 1))
    fi
  done
  echo "Complete. Failed: $failed / ${#IMAGES[@]}"
  [ "$failed" -eq 0 ]
}

main "$@"
