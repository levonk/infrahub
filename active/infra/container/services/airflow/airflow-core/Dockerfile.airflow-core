# airflow-core: Airflow 3.1.2 on base-python (Debian/Alpine via BASE_IMAGE)
# - Installs Apache Airflow using official constraints matching Python minor
# - No credentials baked; supports BuildKit secret mount for pip.conf
# - Preserves non-root runtime user (appuser)

ARG BASE_IMAGE=base-python-debian:latest
ARG AIRFLOW_VERSION=3.1.2

FROM ${BASE_IMAGE} AS runtime

USER root

# Compute Python minor (e.g., 3.14 or 3.13) to select the matching constraints URL
RUN python3 - <<'PY' > /tmp/pyminor
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY

# Install Apache Airflow with constraints; optional BuildKit-mounted pip.conf
# Notes:
# - BuildKit secret id: nexus-pip-conf (mounted to /etc/pip.conf if provided)
# - No secrets are persisted in layers
RUN --mount=type=secret,id=nexus-pip-conf,dst=/etc/pip.conf \
    set -euo pipefail; \
    PY_MINOR="$(cat /tmp/pyminor)"; \
    CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${AIRFLOW_VERSION}-py${PY_MINOR}.txt"; \
    echo "Using constraints: ${CONSTRAINT_URL}"; \
    pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"; \
    rm -f /tmp/pyminor

# Labels and healthcheck placeholder (to be finalized in T023)
LABEL org.opencontainers.image.title="airflow-core" \
      org.opencontainers.image.version="${AIRFLOW_VERSION}" \
      org.opencontainers.image.source="localnet"

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD airflow version >/dev/null 2>&1 || exit 1

USER appuser
WORKDIR /etc/service
