# Paperclip AI Orchestration Service
# Open-source orchestration for zero-human companies
# See: https://github.com/paperclipai/paperclip
#
# Multi-stage build per AGENTS.md Invariant #2:
#   - builder: clones paperclip from GitHub, installs deps, builds
#   - runtime: alpine with only the built artifacts + production deps
#
# Build platform: linux/arm64 (target is OCI cloud server).
# The source is cloned from GitHub during the build — no local source needed.
# Uses the existing `node` user (UID 1000, GID 1000) from the base image.

# ---------------------------------------------------------------------------
# Builder stage — clone and build paperclip from source
# ---------------------------------------------------------------------------
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Install pnpm globally
RUN npm install -g pnpm@9.15.0

# Clone paperclip from GitHub
# Pin to a stable ref for reproducibility. Update the ref when bumping.
ARG PAPERCLIP_REF=master
WORKDIR /usr/src/paperclip
RUN git clone --depth 1 --branch "${PAPERCLIP_REF}" https://github.com/paperclipai/paperclip.git /usr/src/paperclip

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
# Increase Node.js heap size — the UI build (Vite/Rollup) transforms 6000+ modules
# and the default 2GB heap is not enough, especially under multi-arch buildx.
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm build

# Fix package.json exports for production use.
# In a pnpm monorepo, workspace-linked packages use the "exports" field as-is,
# which points to "./src/*.ts" (TypeScript source). But "publishConfig.exports"
# points to "./dist/*.js" (compiled JavaScript). When running in production,
# we need the dist/ paths. This step copies publishConfig.exports → exports
# in all workspace package.json files so Node.js resolves to compiled JS.
RUN printf '%s' 'const fs=require("fs"),path=require("path");' \
      'function fixPkg(p){' \
      'const j=JSON.parse(fs.readFileSync(p,"utf8"));' \
      'if(j.publishConfig&&j.publishConfig.exports){' \
      'j.exports=j.publishConfig.exports;' \
      'fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' \
      'console.log("Fixed:",j.name)}}' \
      'function walk(d){' \
      'for(const e of fs.readdirSync(d,{withFileTypes:true})){' \
      'if(e.name==="node_modules"||e.name===".git")continue;' \
      'const fp=path.join(d,e.name);' \
      'if(e.isDirectory())walk(fp);' \
      'else if(e.name==="package.json")fixPkg(fp)}}' \
      'walk("/usr/src/paperclip");' > /tmp/fix-exports.js && \
    node /tmp/fix-exports.js && \
    rm /tmp/fix-exports.js

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM node:20-alpine AS runtime

# Install pnpm globally
RUN npm install -g pnpm@9.15.0

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    postgresql-client

# Set working directory
WORKDIR /app

# Copy the entire built workspace from the builder.
# Paperclip is a pnpm monorepo — each package builds to its own dist/ directory
# (server/dist, ui/dist, packages/*/dist, cli/dist). There is no top-level dist/.
# We copy the whole workspace (including node_modules with symlinks) to preserve
# the pnpm workspace structure needed at runtime.
COPY --from=builder --chown=node:node /usr/src/paperclip ./

# Prune development dependencies to reduce image size
RUN pnpm prune --prod || true && \
    pnpm store prune || true

# Use the existing node user (UID 1000, GID 1000)
USER node

# Expose Paperclip API port
EXPOSE 3100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://127.0.0.1:3100/health || exit 1

# Set environment variables
ENV NODE_ENV=production \
    PORT=3100

# Start Paperclip server
# The root package.json has no "start" script — the server package does.
# Use pnpm --filter to run the server's start script (node dist/index.js).
CMD ["pnpm", "--filter", "@paperclipai/server", "start"]
