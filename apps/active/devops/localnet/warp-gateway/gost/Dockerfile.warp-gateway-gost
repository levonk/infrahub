FROM base-alpine

ARG GOST_VERSION=3.0.0-rc8
ARG TARGETPLATFORM

RUN case ${TARGETPLATFORM} in \
      "linux/amd64") ARCH="amd64" ;; \
      "linux/arm64") ARCH="arm64" ;; \
      *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    curl -LO https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${ARCH}-${GOST_VERSION}.gz && \
    gunzip gost-linux-${ARCH}-${GOST_VERSION}.gz && \
    mv gost-linux-${ARCH}-${GOST_VERSION} /usr/bin/gost && \
    chmod +x /usr/bin/gost

USER nobody

HEALTHCHECK --interval=30s --timeout=5s \
    CMD curl -sSf --socks5 localhost:1080 http://example.com || exit 1

CMD ["gost", "-L", "socks5://:1080"]
