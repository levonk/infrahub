FROM node:22-bookworm-slim

# Install system dependencies & Python for the shim
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    unzip \
    docker.io \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Set up Python virtual environment
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install Python dependencies for the shim
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Create non-root user
RUN groupadd -r nodejs && useradd -r -g nodejs -m -d /home/nodejs -s /bin/bash nodejs \
    && chown -R nodejs:nodejs /app \
    && chown -R nodejs:nodejs $VIRTUAL_ENV

USER nodejs

# Configure npm
ENV NPM_CONFIG_PREFIX=/home/nodejs/.npm-global
ENV PATH=$PATH:/home/nodejs/.npm-global/bin

# Install bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/nodejs/.bun/bin:$PATH"

# Install oh-my-opencode
RUN bunx oh-my-opencode install --no-tui --claude=no --chatgpt=no --gemini=no \
    && cd /home/nodejs/.config/opencode \
    && bun install

# Copy app code
COPY --chown=nodejs:nodejs app /app/app

# Expose shim port
EXPOSE 8000

# Start shim
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
