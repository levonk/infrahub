#!/usr/bin/env bash
set -euo pipefail

# bootstrap-macos-manual.sh
# Performs the minimal manual steps needed before Ansible can take over
# a fresh macOS machine.
#
# Run this ON the target Mac (not the control machine).
# Must be run as a user with sudo access (the initial admin account).
#
# What it does:
#   1. Enables Remote Login (SSH server)
#   2. Creates the auser admin user
#   3. Adds the SSH public key for auser
#   4. Verifies SSH access is working
#
# After this, run from the control Mac:
#   just ansible-bootstrap-macos
#
# Usage:
#   ./bootstrap-macos-manual.sh                          # interactive — prompts for SSH public key
#   ./bootstrap-macos-manual.sh --ssh-key ~/.ssh/foo.pub # non-interactive — uses specified public key
#   AUSER_PASSWORD="secret" ./bootstrap-macos-manual.sh --ssh-key ~/.ssh/foo.pub  # non-interactive with password

set -euo pipefail

AUSER_NAME="auser"
SSH_KEY=""
PASSWORD=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--ssh-key ~/.ssh/id_rsa.pub] [--password secret]"
      echo ""
      echo "Run ON the target Mac. Creates the auser admin user and adds SSH key."
      echo "If --ssh-key is omitted, you'll be prompted to paste a public key."
      echo "If --password is omitted, the user is created with no password (SSH key auth only)."
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# --- Check we're on macOS ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: This script must be run on macOS (current: $(uname))" >&2
  exit 1
fi

# --- Check sudo access ---
if ! sudo -n true 2>/dev/null; then
  echo "This script needs sudo access. You'll be prompted for your password."
  sudo -v || { echo "ERROR: sudo access required" >&2; exit 1; }
fi

echo "=== macOS Manual Bootstrap ==="
echo "Host: $(hostname)"
echo "OS: $(sw_vers -productVersion) ($(uname -m))"
echo "Admin user: ${AUSER_NAME}"
echo ""

# --- Step 1: Enable Remote Login ---
echo "[1/4] Enabling Remote Login (SSH server)..."
sudo systemsetup -setremotelogin on 2>/dev/null || true
if sudo launchctl list com.openssh.sshd &>/dev/null; then
  echo "  ✓ SSH server is running"
else
  echo "  ⚠ SSH server may not be running — check System Settings → Sharing → Remote Login"
fi
echo ""

# --- Step 2: Create auser ---
echo "[2/4] Creating ${AUSER_NAME} admin user..."
if dscl . -read "/Users/${AUSER_NAME}" UniqueID &>/dev/null; then
  echo "  ✓ ${AUSER_NAME} already exists"
else
  if [[ -n "${PASSWORD}" ]]; then
    sudo sysadminctl -addUser "${AUSER_NAME}" -password "${PASSWORD}" -admin -home "/Users/${AUSER_NAME}"
  else
    # No password — SSH key auth only. sysadminctl -password - prompts interactively.
    # Use -password "" to create with empty password (user must use SSH key).
    sudo sysadminctl -addUser "${AUSER_NAME}" -password "" -admin -home "/Users/${AUSER_NAME}"
  fi
  echo "  ✓ Created ${AUSER_NAME} with admin rights"
fi

# Ensure auser is in admin group (idempotent)
sudo dseditgroup -o edit -a "${AUSER_NAME}" -t user admin 2>/dev/null || true
echo "  ✓ ${AUSER_NAME} is in admin group"
echo ""

# --- Step 3: Add SSH public key ---
echo "[3/4] Adding SSH public key for ${AUSER_NAME}..."

# Get the public key
if [[ -n "${SSH_KEY}" ]]; then
  if [[ ! -f "${SSH_KEY}" ]]; then
    echo "ERROR: SSH key file not found: ${SSH_KEY}" >&2
    exit 1
  fi
  PUB_KEY=$(cat "${SSH_KEY}")
elif [[ -t 0 ]]; then
  # Interactive — prompt for key
  echo "  Paste the SSH public key (from the control Mac's ~/.ssh/lzkmbp2016-micro-oracle.pub):"
  echo "  (paste the entire line starting with ssh-rsa or ssh-ed25519, then press Enter)"
  read -r PUB_KEY
else
  echo "ERROR: No SSH key provided. Use --ssh-key or run interactively." >&2
  exit 1
fi

if [[ -z "${PUB_KEY}" ]]; then
  echo "ERROR: No SSH public key provided" >&2
  exit 1
fi

# Create .ssh directory
sudo mkdir -p "/Users/${AUSER_NAME}/.ssh"
sudo chown "${AUSER_NAME}:staff" "/Users/${AUSER_NAME}/.ssh"
sudo chmod 700 "/Users/${AUSER_NAME}/.ssh"

# Write authorized_keys
echo "${PUB_KEY}" | sudo tee "/Users/${AUSER_NAME}/.ssh/authorized_keys" > /dev/null
sudo chown "${AUSER_NAME}:staff" "/Users/${AUSER_NAME}/.ssh/authorized_keys"
sudo chmod 600 "/Users/${AUSER_NAME}/.ssh/authorized_keys"
echo "  ✓ SSH public key added to /Users/${AUSER_NAME}/.ssh/authorized_keys"
echo ""

# --- Step 4: Verify ---
echo "[4/4] Verification..."
echo "  User: $(dscl . -read "/Users/${AUSER_NAME}" UniqueID 2>/dev/null | awk '{print $2}')"
echo "  Admin group: $(sudo dseditgroup -o checkmember -m "${AUSER_NAME}" admin 2>/dev/null || echo 'NOT in admin group')"
echo "  SSH key: $(sudo cat "/Users/${AUSER_NAME}/.ssh/authorized_keys" | head -c 40)..."

# Get this machine's Tailscale hostname or LAN IP for the hint
TS_HOST=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
if [[ -n "${TS_HOST}" ]]; then
  echo ""
  echo "=== Done! ==="
  echo "From the control Mac, verify SSH access:"
  echo "  ssh ${AUSER_NAME}@${TS_HOST}"
  echo ""
  echo "Then run the Ansible bootstrap:"
  echo "  just ansible-bootstrap-macos"
else
  LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "<mac-ip>")
  echo ""
  echo "=== Done! ==="
  echo "From the control Mac, verify SSH access:"
  echo "  ssh ${AUSER_NAME}@${LAN_IP}"
  echo ""
  echo "Then run the Ansible bootstrap:"
  echo "  just ansible-bootstrap-macos"
fi
