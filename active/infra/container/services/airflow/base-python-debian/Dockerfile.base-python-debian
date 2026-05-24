# base-python (Debian): installs Python in downstream layer
# - FROM airflow-base-common (Debian variant)
# - Builds Python from source to satisfy Python 3.14 requirement deterministically
# - No credentials baked; pip config may be provided via BuildKit secret (nexus-pip-conf)

ARG BASE_IMAGE=airflow-base-common-debian:latest
ARG PYTHON_VERSION=3.14.0

FROM ${BASE_IMAGE} AS builder

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    PY_PREFIX=/usr/local

# Build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      wget \
      libssl-dev \
      zlib1g-dev \
      libbz2-dev \
      libreadline-dev \
      libsqlite3-dev \
      curl \
      libffi-dev \
      liblzma-dev \
      tk-dev \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/python-build

# Download and compile Python from source
RUN wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz \
    && tar -xf Python-${PYTHON_VERSION}.tar.xz \
    && cd Python-${PYTHON_VERSION} \
    && ./configure --enable-optimizations --with-lto --prefix=${PY_PREFIX} \
    && make -j"$(nproc)" \
    && make altinstall

# Create canonical symlinks (python3/pip3)
RUN ln -sf ${PY_PREFIX}/bin/python3.14 ${PY_PREFIX}/bin/python3 \
    && ${PY_PREFIX}/bin/python3 -m ensurepip --upgrade \
    && ln -sf ${PY_PREFIX}/bin/pip3 ${PY_PREFIX}/bin/pip

# Runtime image
FROM ${BASE_IMAGE} AS runtime

USER root

ENV PY_PREFIX=/usr/local

# Copy Python runtime from builder and strip build-time artifacts
COPY --from=builder ${PY_PREFIX}/bin/python3.14 ${PY_PREFIX}/bin/python3.14
COPY --from=builder ${PY_PREFIX}/bin/python3 ${PY_PREFIX}/bin/python3
COPY --from=builder ${PY_PREFIX}/bin/pip3 ${PY_PREFIX}/bin/pip3
COPY --from=builder ${PY_PREFIX}/bin/pip ${PY_PREFIX}/bin/pip
COPY --from=builder ${PY_PREFIX}/lib/python3.14 ${PY_PREFIX}/lib/python3.14
COPY --from=builder ${PY_PREFIX}/include/python3.14 ${PY_PREFIX}/include/python3.14
COPY --from=builder ${PY_PREFIX}/share ${PY_PREFIX}/share

# Optional: mount pip.conf from BuildKit secret (nexus-pip-conf) without persisting secret in layers
# This is a no-op if secret not provided; ensures directory exists for pip to read config
RUN --mount=type=secret,id=nexus-pip-conf,dst=/etc/pip.conf \
    sh -lc 'test -f /etc/pip.conf || true'

# Back to non-root runtime
USER appuser
WORKDIR /etc/service
