FROM verdaccio/verdaccio:latest

# Add curl for healthcheck (stock image doesn't include it)
USER root
RUN apk add --no-cache curl

# Set Verdaccio port from environment variable (default 4873)
ENV VERDACCIO_PORT=4873

# Health check for Verdaccio npm registry
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${VERDACCIO_PORT}/-/ping || exit 1

USER verdaccio
