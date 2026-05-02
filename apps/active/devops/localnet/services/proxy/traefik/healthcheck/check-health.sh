#!/bin/sh
set -e

# Use traefik's built-in healthcheck tool to ping the admin API
/usr/local/bin/traefik healthcheck --ping
