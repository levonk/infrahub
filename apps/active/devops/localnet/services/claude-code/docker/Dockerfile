# Use secure alpine base image
FROM base-alpine

# Install required packages
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S claude && \
    adduser -u 1001 -S claude -G claude

# Set working directory
WORKDIR /app

# Copy configuration templates
COPY cc-tools-config/ ./config/

# Download and install cc-tools from GitHub
RUN git clone https://github.com/Veraticus/cc-tools.git /tmp/cc-tools && \
    cd /tmp/cc-tools && \
    # Assuming cc-tools has installation script or can be copied
    cp -r . /app/cc-tools/ && \
    cd /app && \
    rm -rf /tmp/cc-tools

# Install Python dependencies if any
RUN if [ -f cc-tools/requirements.txt ]; then pip3 install -r cc-tools/requirements.txt; fi

# Create necessary directories
RUN mkdir -p /app/data /app/config /healthcheck

# Set permissions
RUN chown -R claude:claude /app

# Switch to non-root user
USER claude

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Expose port
EXPOSE 8081

# Start command
CMD ["python3", "cc-tools/main.py"]
