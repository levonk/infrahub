FROM sonatype/nexus3:3.85.0-alpine

USER root

RUN apk add --no-cache bash jq su-exec

# Ensure nexus user has proper home directory and Java preferences directory
RUN mkdir -p /opt/sonatype/nexus/.java/.userPrefs \
    && chown -R nexus:nexus /opt/sonatype/nexus/.java \
    && chmod -R 0755 /opt/sonatype/nexus/.java

COPY entrypoint.sh /opt/sonatype/docker-entrypoint.sh
COPY configure-docker-proxy.sh /opt/sonatype/scripts/configure-docker-proxy.sh

RUN chmod 0755 /opt/sonatype/docker-entrypoint.sh \
    && chmod 0755 /opt/sonatype/scripts/configure-docker-proxy.sh

ENV NEXUS_ADMIN_USERNAME=admin \
    NEXUS_ADMIN_PASSWORD= \
    NEXUS_ADMIN_PASSWORD_FILE= \
    NEXUS_DOCKER_PROXY_REMOTE_URL=https://registry-1.docker.io \
    NEXUS_DOCKER_PROXY_PORT=8082 \
    NEXUS_DOCKER_HOSTED_PORT=8083 \
    NEXUS_DOCKER_GROUP_PORT=8084 \
    NEXUS_DOCKER_BLOB_STORE=default \
    NEXUS_DOCKER_V1_ENABLED=false \
    NEXUS_DOCKER_FORCE_BASIC_AUTH=true \
	NEXUS_SKIP_DOCKER_SETUP=false \
	NEXUS_WEB_CONTAINER_PORT=8081

# Health check for Nexus service
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
	CMD curl -f http://localhost:${NEXUS_WEB_CONTAINER_PORT}/service/rest/v1/status || exit 1

ENTRYPOINT ["/opt/sonatype/docker-entrypoint.sh"]
CMD ["nexus", "run"]
