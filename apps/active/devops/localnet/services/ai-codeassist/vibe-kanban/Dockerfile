FROM node:22-bookworm-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    docker.io \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Set working directory
WORKDIR /app

# Create non-root user
RUN groupadd -r nodejs && useradd -r -g nodejs -m -d /home/nodejs -s /bin/bash nodejs \
    && chown -R nodejs:nodejs /app

USER nodejs

# Configure npm/pnpm to use local prefix
ENV NPM_CONFIG_PREFIX=/home/nodejs/.npm-global
ENV PATH=$PATH:/home/nodejs/.npm-global/bin

# Expose port (Vibe Kanban defaults to 3000 or 8080 depending on env)
ENV PORT=3000
EXPOSE 3000

# Default command
CMD ["npx", "-y", "vibe-kanban"]
