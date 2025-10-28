#!/bin/sh

# Ensure runtime directories exist; /run is ephemeral and recreated each start
mkdir -p /run/chrony /var/run/chrony /var/lib/chrony /etc/chrony/certs || true
# Best-effort perms without failing if restricted
chmod 710 /run/chrony /var/run/chrony 2>/dev/null || true
chmod 750 /var/lib/chrony 2>/dev/null || true

## Generate NTS certificates if they don't exist for NTS
chown root:root /etc/chrony || true
chmod 755 /etc/chrony || true
chmod 755 /etc/chrony/certs || true
if [ ! -f /etc/chrony/certs/chrony-nts.crt ] || [ ! -f /etc/chrony/certs/chrony-nts.key ]; then
    echo "[ENTRYPOINT] Generating NTS certificates because /etc/chrony/certs/chrony-nts.{crt,key} missing" >&2
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout /etc/chrony/certs/chrony-nts.key \
        -out /etc/chrony/certs/chrony-nts.crt \
        -days 1 -subj "/CN=chrony-nts"
else
	echo "[ENTRYPOINT] NTS certificates /etc/chrony/certs/chrony-nts.{crt,key} already exist, skipping generation" >&2
fi
chown chrony:chrony /etc/chrony/certs/chrony-nts.crt /etc/chrony/certs/chrony-nts.key || true
chmod 644 /etc/chrony/certs/chrony-nts.crt || true
chmod 600 /etc/chrony/certs/chrony-nts.key || true
if [ "$(stat -c %U /etc/chrony/certs/chrony-nts.key)" != "chrony" ]; then
  echo "[ENTRYPOINT] chown chrony:chrony failed of /etc/chrony/certs/chrony-nts.key"
fi
if [ "$(stat -c %U /etc/chrony/certs/chrony-nts.crt)" != "chrony" ]; then
  echo "[ENTRYPOINT] chown chrony:chrony failed of /etc/chrony/certs/chrony-nts.crt"
fi
echo "[ENTRYPOINT] uid/gid: "
id -u && id -g
echo " "
echo "[ENTRYPOINT] cert mounts: "
mount | grep /etc/chrony/certs
echo " "
echo "[ENTRYPOINT] ls -ld: "
ls -ld /etc/chrony/certs /etc/chrony/certs/*
echo " "

export NTP_CHRONYD_CONTAINER_PORT="${NTP_CHRONYD_CONTAINER_PORT:-123}"
WORKING_DIR="/etc/chrony"
WORKING_CONFIG="${WORKING_DIR}/chrony.conf"
TEMPLATE_CONFIG="/templates${WORKING_CONFIG}.template"

sed_expressions=""
while IFS='=' read -r -d '' name value; do
    if [[ "$name" == NTP_CHRONYD_* ]]; then
        echo "[ENTRYPOINT] Substituting ${name}=${value}" >&2
        # Add a sed expression for the current variable
        sed_expressions+="-e 's|{${name}}|${value}|g' "
    fi
done < <(printenv -0)

# Substitute all variables in one pass
if [ -n "$sed_expressions" ]; then
    # Use eval to correctly handle the space-separated sed expressions
    eval sed "$sed_expressions" "$TEMPLATE_CONFIG" > "$WORKING_CONFIG"
fi

echo '[ENTRYPOINT] First boot error of "Could not read valid frequency and skew from driftfile /var/lib/chrony/chrony.drift" is expected and can be ignored.' >&2

# Start chronyd as root so it can bind to low ports, then drop to 'chrony'
exec /usr/sbin/chronyd -u chrony -d -x -s "$@"
