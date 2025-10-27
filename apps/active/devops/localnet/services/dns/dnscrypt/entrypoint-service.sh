#!/bin/sh
# /home/micro/p/gh/lrepo52/job-aide-wt01/apps/active/devops/localnet/services/dns/dnscrypt/entrypoint-service.sh


set -e

CONFIG_FILE="$1"

if [ -z "$CONFIG_FILE" ]; then
  echo "Error: Configuration file path not provided." >&2
  exit 1
fi

TEMPLATE_FILE="${CONFIG_FILE}.template"

# Substitute all possible dnscrypt variables. 
# It's safe if a variable doesn't exist in a specific template.
sed -e "s/{DNS_DNSCRYPT_ODOH_CONTAINER_PORT}/${DNS_DNSCRYPT_ODOH_CONTAINER_PORT}/g" \
    -e "s/{DNS_DNSCRYPT_ANON_CONTAINER_PORT}/${DNS_DNSCRYPT_ANON_CONTAINER_PORT}/g" \
    -e "s/{DNS_DNSCRYPT_STD_CONTAINER_PORT}/${DNS_DNSCRYPT_STD_CONTAINER_PORT}/g" \
    -e "s/{DNS_DNSCRYPT_DOH_CONTAINER_PORT}/${DNS_DNSCRYPT_DOH_CONTAINER_PORT}/g" \
    -e "s/{DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT}/${DNS_DNSCRYPT_ENCRYPTED_CONTAINER_PORT}/g" \
    -e "s/{DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT}/${DNS_DNSCRYPT_PLAINTEXT_CONTAINER_PORT}/g" \
    "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Start dnscrypt-proxy with the generated config
exec /usr/sbin/dnscrypt-proxy -config "$CONFIG_FILE"
