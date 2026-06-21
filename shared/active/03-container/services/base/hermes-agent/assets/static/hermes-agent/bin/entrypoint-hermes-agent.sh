#!/bin/sh
set -e

echo "Starting Hermes Agent container..."
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"
echo "Working directory: $(pwd)"
echo "Shell: $SHELL"

# Verify Docker socket access
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket is accessible"
    docker version > /dev/null 2>&1 && echo "Docker CLI is functional" || echo "Warning: Docker CLI not functional"
else
    echo "Warning: Docker socket not found at /var/run/docker.sock"
fi

# Verify Nix integration
if [ -d /nix ]; then
    echo "Nix store is mounted"
    nix --version > /dev/null 2>&1 && echo "Nix is functional" || echo "Warning: Nix not functional"
else
    echo "Warning: Nix store not mounted"
fi

# Create data directories if they don't exist
mkdir -p "${HERMES_DATA_DIR}" "${HERMES_CONFIG_DIR}"

# Start SSH server
echo "Starting SSH server on port ${SSH_PORT:-22}"
/usr/sbin/sshd -D -e "${SSH_PORT:-22}" &
SSH_PID=$!

# Start Tailscale if auth key is provided
if [ -n "${TAILSCALE_AUTH_KEY}" ]; then
    echo "Starting Tailscale with provided auth key"
    tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --hostname="hermes-agent" || echo "Warning: Tailscale failed to start"
else
    echo "No Tailscale auth key provided, skipping Tailscale setup"
fi

# Start Netbird if setup key is provided
if [ -n "${NETBIRD_SETUP_KEY}" ]; then
    echo "Starting Netbird with provided setup key"
    netbird up --setup-key "${NETBIRD_SETUP_KEY}" --hostname "hermes-agent" || echo "Warning: Netbird failed to start"
else
    echo "No Netbird setup key provided, skipping Netbird setup"
fi

echo "Hermes Agent container initialized successfully"
echo "Ready for Docker operations"
echo "SSH server running on port ${SSH_PORT:-22}"
echo "Shell: zsh (with tmux available)"

# Keep container running and monitor SSH
wait $SSH_PID
