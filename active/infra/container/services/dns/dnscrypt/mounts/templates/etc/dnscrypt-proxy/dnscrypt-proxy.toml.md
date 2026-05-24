# DO NOT EDIT UNLESS IT'S IN `${REPO_ROOT}/apps/devops/localnet/services/dns/dnscrypt/mounts/templates/etc/dnscrypt-proxy`

# If you're in `/etc/dnscrypt-proxy/` INSIDE the container, you are making changes to the processed ephemeral file

Do NOT put dnscrypt-proxy.toml in here.  The `entrypoint-dnscrypt.sh` script will generate the configuration at runtime based on environment variables and mount points.
