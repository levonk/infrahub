#!/usr/bin/env bash
# Build and push all locally-built images to the local Docker registry.
#
# Uses `docker buildx` for native multi-arch builds (linux/amd64,linux/arm64)
# in a single command — no legacy `docker build --platform` deprecation warning,
# no manual `docker manifest` hack.
#
# Usage:
#   scripts/build-and-push-images.sh                  # build + push all (skips unchanged)
#   scripts/build-and-push-images.sh headroom          # build + push one image
#   scripts/build-and-push-images.sh --list            # list all images
#   scripts/build-and-push-images.sh --force           # force rebuild all (ignore cache)
#   scripts/build-and-push-images.sh --check headroom  # exit 0 if up-to-date, 1 if stale/missing
#   FORCE_REBUILD=1 scripts/build-and-push-images.sh headroom  # force rebuild one
#   PLATFORMS=linux/amd64 scripts/build-and-push-images.sh localnet-p2p-freenet  # override platforms
#
# Per AGENTS.md Invariant #2: build on Mac → push to registry → pull on target.
# NEVER build on the target host.
#
# Host architecture map: levonk/active/02-config/ansible/infrastructure/hosts.yml
#   cno (oci-cloud-server, kckinai)  → arm64
#   nl  (dtop202311)                 → amd64
#   isolation-vm                     → amd64
# Default PLATFORMS builds BOTH so a single image serves every host.
set -euo pipefail

REGISTRY="${REGISTRY:-100.90.22.85:5000}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICES="$ROOT/shared/active/03-container/services"
# Default: build both architectures so one :latest tag serves all hosts.
# Override per-invocation with PLATFORMS env var (e.g. for single-arch images).
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Local ctxhash cache — records the context hash of the last successful push
# per image, so deploy recipes can detect staleness without inspecting the
# remote manifest (which is unreliable for multi-arch builds).
CACHE_DIR="$ROOT/.cache/scripts/build-and-push"
CTXHASH_CACHE="$CACHE_DIR/ctxhashes.json"

# Image name | Dockerfile (relative to context dir) | Context dir (relative to SERVICES) | Platforms (optional override)
# The 4th field is optional; empty means use $PLATFORMS.
IMAGES=(
  "localnet-agentmemory|docker/Dockerfile.agentmemory|agentmemory|"
  "localnet-dns-adguard|Dockerfile.adguard|dns/adguard|"
  "localnet-dns-blocklist-compiler|Dockerfile.blocklist-compiler|dns/dns-blocklists|"
  "localnet-dns-coredns|docker/Dockerfile.coredns|dns/coredns|"
  "localnet-dns-dnscrypt-plaintext|docker/Dockerfile.dnscrypt-proxy|dns/dnscrypt|"
  "localnet-dns-dnsdist|docker/Dockerfile.dnsdist|dns/dnsdist|"
  "localnet-proxy-tor|docker/Dockerfile.tor|proxy/tor|"
  "localnet-proxy-9router|Dockerfile|proxy/9router|"
  "localnet-base-alpine|Dockerfile.base-alpine|base/base-alpine|"
  "isolation-vm-base-kali|Dockerfile.base-kali|base/base-kali|"
  "isolation-vm-base-kalinix|Dockerfile.base-kalinix|base/base-kalinix|"
  "isolation-vm-hermes-agent|Dockerfile.hermes-agent|base/hermes-agent|"
  "isolation-vm-nix-sidecar|Dockerfile.nix-sidecar|base/nix-sidecar|"
  "localnet-ai-omniroute|docker/Dockerfile.omniroute|ai-services/omniroute|"
  "headroom|Dockerfile.headroom|ai-codeassist/headroom|"
  "localnet-ai-paperclip|Dockerfile|ai-codeassist/paperclip|"
  # Freenet peer node — linux/amd64 ONLY (target: Windows Docker Desktop, nl).
  "localnet-p2p-freenet|docker/Dockerfile.freenet|p2p/freenet|linux/amd64"
)

# NOTE: envoy, privoxy, squid use upstream Docker Hub images directly (no custom Dockerfile).
# See roles/forward-proxy/tasks/{envoy,privoxy,squid}.yml for the upstream image references.

# --- ctxhash cache helpers (JSON via jq) ---
ensure_cache() {
  mkdir -p "$CACHE_DIR"
  [ -f "$CTXHASH_CACHE" ] || echo '{}' > "$CTXHASH_CACHE"
}

cache_get() {  # <image-name> → hash or empty
  ensure_cache
  jq -r --arg name "$1" '.[$name] // empty' "$CTXHASH_CACHE" 2>/dev/null || true
}

cache_set() {  # <image-name> <hash>
  ensure_cache
  local tmp
  tmp="$(mktemp)"
  jq --arg name "$1" --arg hash "$2" '.[$name] = $hash' "$CTXHASH_CACHE" > "$tmp" && mv "$tmp" "$CTXHASH_CACHE"
}

compute_ctxhash() {  # <context-path> → hash
  # Sort the file list + hashes for deterministic output across runs.
  find "$1" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -c1-12
}

list_images() {
  for entry in "${IMAGES[@]}"; do
    IFS='|' read -r name dockerfile context platforms <<< "$entry"
    local plat="${platforms:-$PLATFORMS}"
    printf "  %-40s %-45s [platforms=%s]\n" "$name" "($dockerfile)" "$plat"
  done
}

# Returns 0 if up-to-date (cached hash matches AND manifest exists), 1 if stale/missing.
is_stale() {  # <name> <ctx-path>
  local name="$1" ctx_path="$2"
  if [ "${FORCE_REBUILD:-0}" = "1" ]; then
    return 0  # forced → treat as stale
  fi
  # Must exist in registry. Use curl (not `docker manifest inspect`) because
  # the local registry is HTTP-only and the Docker CLI forces HTTPS for manifest
  # inspection, returning false "no such manifest" errors.
  if ! curl -sf -o /dev/null \
       -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json" \
       "http://$REGISTRY/v2/$name/manifests/latest" 2>/dev/null; then
    return 0  # missing → stale
  fi
  # Context hash must match last successful build.
  local current_hash cached_hash
  current_hash="$(compute_ctxhash "$ctx_path")"
  cached_hash="$(cache_get "$name")"
  if [ "$current_hash" != "$cached_hash" ]; then
    return 0  # context changed → stale
  fi
  return 1  # up-to-date
}

build_and_push() {  # <name> <dockerfile> <context> <platforms-override>
  local name="$1" dockerfile="$2" context="$3" platforms_override="$4"
  local platforms="${platforms_override:-$PLATFORMS}"
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

  local ctx_hash
  ctx_hash="$(compute_ctxhash "$ctx_path")"
  local label="ctxhash=$ctx_hash"

  # Staleness check (skipped under FORCE_REBUILD).
  if [ "${FORCE_REBUILD:-0}" != "1" ]; then
    local cached_hash
    cached_hash="$(cache_get "$name")"
    local manifest_ok=0
    # Use curl (not `docker manifest inspect`) — see is_stale() for rationale.
    curl -sf -o /dev/null \
      -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json" \
      "http://$REGISTRY/v2/$name/manifests/latest" 2>/dev/null && manifest_ok=1
    if [ "$manifest_ok" = "1" ] && [ "$ctx_hash" = "$cached_hash" ]; then
      echo "CACHED: $name — manifest present and context hash unchanged ($ctx_hash), skipping"
      return 0
    fi
  fi

  echo "BUILD: $name  ($df_path)  [platforms=$platforms, ctxhash=$ctx_hash]"
  # Auto-inject --build-context overrides for any localnet-base-* base images
  # referenced in the Dockerfile, so buildx's container driver resolves them
  # from the local registry instead of Docker Hub. No Dockerfile edits needed.
  local build_context_args=()
  local base_images
  base_images=$(grep -iE '^FROM[[:space:]]+localnet-base-[a-z]+' "$df_path" 2>/dev/null \
    | sed -E 's/^FROM[[:space:]]+([^[:space:]]+).*/\1/i' \
    | sort -u || true)
  if [ -n "$base_images" ]; then
    while IFS= read -r base; do
      build_context_args+=(--build-context "${base}=docker-image://${REGISTRY}/${base}")
    done <<< "$base_images"
  fi
  # buildx builds all platforms and pushes the multi-arch manifest in one command.
  # --push replaces the separate `docker push` step; no local image is loaded.
  docker buildx build \
    --platform "$platforms" \
    --label "$label" \
    -t "$full_tag" \
    --push \
    "${build_context_args[@]+"${build_context_args[@]}"}" \
    -f "$df_path" \
    "$ctx_path"
  # Record the context hash of this successful push.
  cache_set "$name" "$ctx_hash"
  echo "DONE:  $name  (pushed $platforms → $full_tag)"
  echo
}

# --check mode: exit 0 if up-to-date, 1 if stale/missing. No build.
check_mode() {  # <image-name>
  local target="$1"
  local found=0
  for entry in "${IMAGES[@]}"; do
    IFS='|' read -r name dockerfile context platforms_override <<< "$entry"
    if [ "$name" = "$target" ]; then
      found=1
      local ctx_path="$SERVICES/$context"
      if [ ! -d "$ctx_path" ]; then
        echo "STALE: $target — context dir not found" >&2
        return 1
      fi
      if is_stale "$name" "$ctx_path"; then
        echo "STALE: $target — needs build"
        return 1
      else
        echo "FRESH: $target — up-to-date"
        return 0
      fi
    fi
  done
  if [ "$found" = "0" ]; then
    echo "ERROR: Unknown image '$target'. Use --list to see available images." >&2
    return 1
  fi
}

main() {
  if [ "${1:-}" = "--list" ]; then
    list_images
    return 0
  fi

  if [ "${1:-}" = "--check" ]; then
    shift
    [ $# -gt 0 ] || { echo "ERROR: --check requires an image name" >&2; return 2; }
    check_mode "$1"
    return $?
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
        IFS='|' read -r name dockerfile context platforms_override <<< "$entry"
        if [ "$name" = "$target" ]; then
          build_and_push "$name" "$dockerfile" "$context" "$platforms_override"
          found=1
          break
        fi
      done
      if [ "$found" = "0" ]; then
        echo "ERROR: Unknown image '$target'. Use --list to see available images." >&2
        return 1
      fi
    done
    return 0
  fi

  # Build all
  echo "Building and pushing ${#IMAGES[@]} images to $REGISTRY (platforms=$PLATFORMS)"
  echo
  local failed=0
  for entry in "${IMAGES[@]}"; do
    IFS='|' read -r name dockerfile context platforms_override <<< "$entry"
    if ! build_and_push "$name" "$dockerfile" "$context" "$platforms_override"; then
      failed=$((failed + 1))
    fi
  done
  echo "Complete. Failed: $failed / ${#IMAGES[@]}"
  [ "$failed" -eq 0 ]
}

main "$@"
