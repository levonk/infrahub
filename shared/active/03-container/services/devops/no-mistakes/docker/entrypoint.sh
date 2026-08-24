#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# no-mistakes shared gate — container entrypoint
#
# 1. Generate SSH host keys if not present (idempotent across restarts)
# 2. Ensure gate user directories exist and are owned by gate
# 3. Copy config.yaml / authorized_keys if mounted into /home/gate
# 4. Start the no-mistakes daemon as the gate user
# 5. Start sshd in the foreground (PID 1)
# ---------------------------------------------------------------------------

# Generate SSH host keys if not present (volume-mounted /etc/ssh may be empty)
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  echo "[entrypoint] Generating SSH host keys..."
  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C "no-mistakes-gate"
fi

# Ensure gate user directories exist
mkdir -p /home/gate/.no-mistakes/repos
mkdir -p /home/gate/.no-mistakes/worktrees
mkdir -p /home/gate/.no-mistakes/logs
chown -R gate:gate /home/gate/.no-mistakes

# Copy config if provided (Ansible renders config.yaml.j2 → config.yaml at deploy)
if [ -f /home/gate/config.yaml ]; then
  cp /home/gate/config.yaml /home/gate/.no-mistakes/config.yaml
  chown gate:gate /home/gate/.no-mistakes/config.yaml
  echo "[entrypoint] Config copied to \$NM_HOME/config.yaml"
fi

# Copy authorized_keys if provided (Ansible mounts the gate public key)
if [ -f /home/gate/authorized_keys ]; then
  cp /home/gate/authorized_keys /home/gate/.ssh/authorized_keys
  chmod 600 /home/gate/.ssh/authorized_keys
  chown gate:gate /home/gate/.ssh/authorized_keys
  echo "[entrypoint] authorized_keys installed"
fi

# Start no-mistakes daemon as gate user (best-effort — daemon may already be running)
echo "[entrypoint] Starting no-mistakes daemon..."
su -s /bin/bash gate -c "no-mistakes daemon start" || true

# Start sshd in the foreground
echo "[entrypoint] Starting sshd on port 2222..."
exec /usr/sbin/sshd -D
