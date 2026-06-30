#!/usr/bin/env bash
# Build and push all locally-built images to the local Docker registry.
#
# Usage:
#   scripts/build-and-push-images.sh           # build + push all
#   scripts/build-and-push-images.sh headroom   # build + push one image
#   scripts/build-and-push-images.sh --list     # list all images
#
# Per AGENTS.md Invariant #2: build on Mac → push to registry → pull on target.
# NEVER build on the target host.
set -euo pipefail

REGISTRY="${REGISTRY:-100.90.22.85:5000}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICES="$ROOT/shared/active/03-container/services"
# Target platform — OCI server is aarch64. Build for that platform.
PLATFORM="${PLATFORM:-linux/arm64}"

# Image name | Dockerfile (relative to context) | Context dir (relative to SERVICES)
IMAGES=(
  "localnet-agentmemory|agentmemory/docker/Dockerfile.agentmemory|agentmemory"
  "localnet-dns-adguard|dns/adguard/Dockerfile.adguard|dns/adguard"
  "localnet-dns-blocklist-compiler|dns/dns-blocklists/Dockerfile.blocklist-compiler|dns/dns-blocklists"
  "localnet-dns-coredns|dns/coredns/docker/Dockerfile.coredns|dns/coredns"
  "localnet-dns-dnscrypt-plaintext|dns/dnscrypt/docker/Dockerfile.dnscrypt-proxy|dns/dnscrypt"
  "localnet-dns-dnsdist|dns/dnsdist/docker/Dockerfile.dnsdist|dns/dnsdist"
  "localnet-proxy-tor|proxy/tor/docker/Dockerfile.tor|proxy/tor"
  "localnet-proxy-9router|proxy/9router/Dockerfile|proxy/9router"
  "localnet-base-alpine|base/base-alpine/Dockerfile.base-alpine|base/base-alpine"
  "isolation-vm-base-kali|base/base-kali/Dockerfile.base-kali|base/base-kali"
  "isolation-vm-base-kalinix|base/base-kalinix/Dockerfile.base-kalinix|base/base-kalinix"
  "isolation-vm-hermes-agent|base/hermes-agent/Dockerfile.hermes-agent|base/hermes-agent"
  "isolation-vm-nix-sidecar|base/nix-sidecar/Dockerfile.nix-sidecar|base/nix-sidecar"
  "localnet-ai-omniroute|ai-services/omniroute/docker/Dockerfile.omniroute|ai-services/omniroute"
  "headroom|ai-codeassist/headroom/Dockerfile.headroom|ai-codeassist/headroom"
)

# TODO: Dockerfiles missing for these (forward-proxy role):
#   localnet-proxy-envoy   (proxy/envoy/docker/Dockerfile.envoy)
#   localnet-proxy-privoxy (proxy/privoxy/docker/Dockerfile.privoxy)
#   localnet-proxy-squid   (proxy/squid/docker/Dockerfile.squid)

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

  echo "BUILD: $name  ($df_path)  [platform=$PLATFORM]"
  docker build --platform "$PLATFORM" -t "$full_tag" -f "$df_path" "$ctx_path"
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
