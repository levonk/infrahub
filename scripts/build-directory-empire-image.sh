#!/usr/bin/env bash
# Build and push the Directory Empire dashboard image to the local registry.
#
# The Dockerfile lives in the directory-empire repo (lrepo52/directory-empire),
# not in infrahub's services directory. This script:
#   1. Clones the repo to a temp directory (SSH — works on the Mac)
#   2. Builds the multi-stage Docker image (linux/amd64 only — target is Windows)
#   3. Pushes to the local registry (100.90.22.85:5000)
#
# Usage:
#   scripts/build-directory-empire-image.sh              # build + push
#   scripts/build-directory-empire-image.sh --check       # exit 0 if up-to-date, 1 if stale
#   FORCE_REBUILD=1 scripts/build-directory-empire-image.sh  # force rebuild
#
# Per AGENTS.md Invariant #2: build on Mac → push to registry → pull on target.
set -euo pipefail

REGISTRY="${REGISTRY:-100.90.22.85:5000}"
IMAGE_NAME="${REGISTRY}/localnet-dashboard-directory-empire"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPO_URL="git@github-5:lrepo52/directory-empire.git"
REPO_BRANCH="${REPO_BRANCH:-main}"
PLATFORMS="${PLATFORMS:-linux/amd64}"  # Target: Windows Docker Desktop (X86 only)

# --- Context hash for staleness detection ---
CACHE_DIR="$HOME/p/gh/levonk/infrahub/.cache/scripts/build-and-push"
CTXHASH_CACHE="$CACHE_DIR/ctxhashes.json"
ensure_cache() {
  mkdir -p "$CACHE_DIR"
  [ -f "$CTXHASH_CACHE" ] || echo '{}' > "$CTXHASH_CACHE"
}

# --- Use local repo if available, otherwise clone ---
LOCAL_REPO="$HOME/p/gh/lrepo52/directory-empire"
TMPDIR=$(mktemp -d /tmp/directory-empire-build-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

if [[ -d "$LOCAL_REPO/Dockerfile" || -f "$LOCAL_REPO/Dockerfile" ]]; then
  echo "==> Using local directory-empire repo at $LOCAL_REPO"
  REPO_DIR="$LOCAL_REPO"
else
  echo "==> Cloning directory-empire repo (branch: $REPO_BRANCH)..."
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMPDIR/repo"
  REPO_DIR="$TMPDIR/repo"
fi

# --- Check mode: compare context hash ---
if [[ "${1:-}" == "--check" ]]; then
  ensure_cache
  NEW_HASH=$(find "$REPO_DIR" -type f \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -exec shasum -a 256 {} + | sort | shasum -a 256 | cut -d' ' -f1)
  OLD_HASH=$(jq -r --arg name "localnet-dashboard-directory-empire" '.[$name] // empty' "$CTXHASH_CACHE" 2>/dev/null || true)
  if [[ "$NEW_HASH" == "$OLD_HASH" ]]; then
    echo "✓ localnet-dashboard-directory-empire is up-to-date (context hash matches)"
    exit 0
  else
    echo "⚠ localnet-dashboard-directory-empire is stale (context hash differs)"
    exit 1
  fi
fi

# --- Build ---
echo "==> Building $IMAGE_NAME:$IMAGE_TAG ($PLATFORMS)..."
docker buildx build \
  --platform "$PLATFORMS" \
  --tag "$IMAGE_NAME:$IMAGE_TAG" \
  --push \
  "$REPO_DIR"

# --- Record context hash ---
ensure_cache
NEW_HASH=$(find "$REPO_DIR" -type f \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -exec shasum -a 256 {} + | sort | shasum -a 256 | cut -d' ' -f1)
TMP_JSON=$(mktemp)
jq --arg name "localnet-dashboard-directory-empire" --arg hash "$NEW_HASH" \
  '.[$name] = $hash' "$CTXHASH_CACHE" > "$TMP_JSON" && mv "$TMP_JSON" "$CTXHASH_CACHE"

echo "✓ Built and pushed $IMAGE_NAME:$IMAGE_TAG"
echo "  Verify: docker manifest inspect $IMAGE_NAME:$IMAGE_TAG"
