# Airflow base-common (Debian): adds tzdata + tini on top of internal base-debian
# - Inherits non-root appuser, healthcheck, and hardening from base image
# - Do not add anything else here; Python is installed in downstream layers

ARG BASE_IMAGE=base-debian:latest
FROM ${BASE_IMAGE}

USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tzdata \
        tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Return to the hardened non-root user defined by the base image
USER appuser

WORKDIR /etc/service
