# Pi Dockerfile
# Minimal terminal coding harness — the agent that does the coding work.
# Omnigent's runner drives pi via RPC mode (JSONL over stdin/stdout).
# Reference: https://github.com/earendil-works/pi
FROM node:22-slim

LABEL maintainer="levonk"
LABEL description="Pi - minimal terminal coding harness (RPC mode for Omnigent integration)"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (node image already has gid 1000 for 'node' group)
RUN groupadd -g 1001 pi && \
    useradd -u 1001 -g pi -s /bin/bash -m pi

# Install pi coding agent globally
# --ignore-scripts disables dependency lifecycle scripts during install (per pi docs)
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Create data and workspace directories
RUN mkdir -p /data/sessions /workspace && \
    chown -R pi:pi /data /workspace

# Copy the RPC HTTP bridge script
COPY rpc-bridge.py /app/rpc-bridge.py
RUN chmod +x /app/rpc-bridge.py && chown pi:pi /app/rpc-bridge.py

# Configure pi to use the pipeline entry as its LLM endpoint.
# pi reads custom providers from ~/.pi/agent/models.json.
# The pipeline entry (AI Dashboard Proxy 1) speaks OpenAI-compatible API.
COPY --chown=pi:pi models.json /home/pi/.pi/agent/models.json

# Install pi-windsurf plugin as the pi user (installs to ~/.pi/agent/)
# The plugin runs a local proxy at 127.0.0.1:42100 that translates OpenAI API →
# Windsurf's Connect-RPC wire format. No separate API keys needed.
USER pi
RUN pi install npm:pi-windsurf

# Switch back to non-root user for runtime
WORKDIR /workspace

# Health check — the RPC bridge exposes /health
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:${PI_RPC_PORT:-8090}/health || exit 1

# Expose RPC bridge port
EXPOSE 8090

# Start the RPC HTTP bridge — it spawns `pi --mode rpc` per session and
# proxies HTTP requests to the subprocess stdin/stdout.
CMD ["python3", "/app/rpc-bridge.py"]
