# Forge Dockerfile
# Tool calling reliability layer for LLMs
FROM python:3.12-slim

LABEL maintainer="levonk"
LABEL description="Forge - Tool calling reliability layer for LLMs"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 forge && \
    useradd -u 1000 -g forge -s /bin/bash -m forge

# Set working directory
WORKDIR /app

# Copy requirements and install forge
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Create data directory
RUN mkdir -p /data && chown -R forge:forge /data

# Switch to non-root user
USER forge

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Default command - proxy server
CMD ["python", "-m", "forge.proxy", "--backend-url", "http://headroom:8787", "--port", "8081"]

# Expose port
EXPOSE 8081
