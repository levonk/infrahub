# Airflow base-common (Alpine): adds tzdata + tini on top of internal base-alpine
# - Inherits non-root appuser, healthcheck, and hardening from base image
# - Do not add anything else here; Python is installed in downstream layers

ARG BASE_IMAGE=base-alpine:latest
FROM ${BASE_IMAGE}

USER root

RUN apk update \
    && apk add --no-cache \
        tzdata \
        tini \
    && rm -rf /var/cache/apk/* /tmp/*

# Return to the hardened non-root user defined by the base image
USER appuser

WORKDIR /etc/service
