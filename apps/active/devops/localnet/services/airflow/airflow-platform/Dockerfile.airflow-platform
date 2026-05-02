# airflow-platform: Airflow 3.1.2 + selected providers on base-python
# - Providers: cncf.kubernetes, postgres, http, slack (version ranges must be compatible with Airflow 3.1.x)
# - Uses Airflow constraints matching Python minor to avoid pin drift
# - No credentials baked; supports BuildKit secret mount for pip.conf
# - Preserves non-root runtime user (appuser)

ARG BASE_IMAGE=base-python-debian:latest
ARG AIRFLOW_VERSION=3.1.2

FROM ${BASE_IMAGE} AS runtime

USER root

# Determine Python minor for constraints file selection
RUN python3 - <<'PY' > /tmp/pyminor
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY

# Install Apache Airflow and compatible providers using constraints
RUN --mount=type=secret,id=nexus-pip-conf,dst=/etc/pip.conf \
    set -euo pipefail; \
    PY_MINOR="$(cat /tmp/pyminor)"; \
    CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${AIRFLOW_VERSION}-py${PY_MINOR}.txt"; \
    echo "Using constraints: ${CONSTRAINT_URL}"; \
    pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"; \
    # Providers: prefer ranges compatible with Airflow 3.1.x; rely on constraints to resolve exact pins
    pip install --no-cache-dir \
      'apache-airflow-providers-cncf-kubernetes>=9,<10' \
      'apache-airflow-providers-postgres>=7,<8' \
      'apache-airflow-providers-http>=5,<6' \
      'apache-airflow-providers-slack>=9,<10' \
      --constraint "${CONSTRAINT_URL}"; \
    rm -f /tmp/pyminor

LABEL org.opencontainers.image.title="airflow-platform" \
      org.opencontainers.image.version="${AIRFLOW_VERSION}" \
      org.opencontainers.image.source="localnet"

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD airflow version >/dev/null 2>&1 || exit 1

USER appuser
WORKDIR /etc/service
