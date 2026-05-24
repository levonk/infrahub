# base-python (Alpine): installs Python in downstream layer
# - FROM airflow-base-common (Alpine variant)
# - Prefer apk-provided Python 3.14; allow temporary fallback to 3.13 (per spec)
# - No credentials baked; pip config may be provided via BuildKit secret (nexus-pip-conf)

ARG BASE_IMAGE=airflow-base-common-alpine:latest
# Comma-separated list of acceptable minor versions (order matters: prefer leftmost)
ARG ALPINE_PY_ACCEPT="3.14,3.13"

FROM ${BASE_IMAGE} AS runtime

USER root

# Install python and pip from Alpine repositories
RUN apk update \
    && apk add --no-cache \
        python3 \
        py3-pip \
    && rm -rf /var/cache/apk/* /tmp/*

# Validate that installed Python minor version is in the allowed set (default: 3.14 or 3.13)
# This enforces the "prefer 3.14; fallback 3.13" policy without hardcoding apk versions
ENV ALPINE_PY_ACCEPT=${ALPINE_PY_ACCEPT}
RUN python3 - <<'PY'
import os, sys
minor=f"{sys.version_info.major}.{sys.version_info.minor}"
allowed=[x.strip() for x in os.environ.get("ALPINE_PY_ACCEPT","3.14,3.13").split(',') if x.strip()]
if minor not in allowed:
    raise SystemExit(f"Unsupported Python minor: {minor}; allowed: {allowed}")
print(f"Python {minor} accepted")
PY

# Optional: mount pip.conf from BuildKit secret (nexus-pip-conf) without persisting secret in layers
RUN --mount=type=secret,id=nexus-pip-conf,dst=/etc/pip.conf \
    sh -lc 'test -f /etc/pip.conf || true'

# Ensure pip is available as `pip`
RUN ln -sf /usr/bin/pip3 /usr/local/bin/pip || true

# Back to non-root runtime
USER appuser
WORKDIR /etc/service
