# airflow-py: Task image based on base-python (no Airflow)
# - Provides Python runtime consistent with base-python images
# - Supports BuildKit secret mount for pip.conf; no credentials baked
# - Preserves non-root runtime user (appuser)

ARG BASE_IMAGE=base-python-debian:latest

FROM ${BASE_IMAGE} AS runtime

USER root

# Optional: validate Python and pip presence; allow pip.conf secret mount
RUN --mount=type=secret,id=nexus-pip-conf,dst=/etc/pip.conf \
    python3 --version && pip --version && true

# Labels placeholder; refined later
LABEL org.opencontainers.image.title="airflow-py" \
      org.opencontainers.image.source="localnet"

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python3 --version >/dev/null 2>&1 || exit 1

USER appuser
WORKDIR /etc/service
