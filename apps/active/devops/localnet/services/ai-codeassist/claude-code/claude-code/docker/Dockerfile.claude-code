# Use secure alpine base image with Python support for session management API
FROM base-alpine

# Install required packages
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    postgresql-client \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S claude && \
    adduser -u 1001 -S claude -G claude

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY docker/requirements.txt ./

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application code
COPY docker/main.py ./
COPY docker/auth-service/ ./auth-service/

# Copy cc-tools for potential integration (if needed)
RUN git clone https://github.com/Veraticus/cc-tools.git /tmp/cc-tools && \
    cp -r /tmp/cc-tools/cc-tools /app/ && \
    rm -rf /tmp/cc-tools

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/config /healthcheck && \
    chown -R claude:claude /app

# Switch to non-root user
USER claude

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Expose port
EXPOSE 8081

# Start command
CMD ["python3", "main.py"]
