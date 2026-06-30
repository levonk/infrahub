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
#   ./bootstrap-macos-manual.sh                          # uses embedded default key (lzkmbp2016-micro-oracle)
#   ./bootstrap-macos-manual.sh --ssh-key ~/.ssh/foo.pub # override — uses specified public key file
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
      echo "If --ssh-key is omitted, uses the embedded default key (lzkmbp2016-micro-oracle)."
      echo "If --password is omitted, you will be prompted to enter a password interactively."
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
# systemsetup -setremotelogin requires Full Disk Access on macOS 15+ (Sequoia).
# Fall back to launchctl if it fails, then verify the actual state.
echo "[1/4] Enabling Remote Login (SSH server)..."
REMOTE_LOGIN_STATE=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
if [[ "${REMOTE_LOGIN_STATE}" == *"On"* ]]; then
  echo "  ✓ Remote Login already on"
else
  if sudo systemsetup -setremotelogin on 2>/dev/null; then
    echo "  ✓ Remote Login enabled (systemsetup)"
  else
    echo "  ⚠ systemsetup failed (needs Full Disk Access on macOS 15+) — trying launchctl fallback..."
    sudo launchctl enable system/com.openssh.sshd 2>/dev/null || true
    sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || \
      sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
  fi
fi
# Verify the actual state — don't trust the command's exit code
REMOTE_LOGIN_STATE=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "")
if [[ "${REMOTE_LOGIN_STATE}" == *"On"* ]]; then
  echo "  ✓ Remote Login is ON"
elif sudo launchctl list com.openssh.sshd &>/dev/null; then
  echo "  ✓ SSH server is running (launchctl)"
else
  echo "  ✗ ERROR: Remote Login could not be enabled." >&2
  echo "    Grant Full Disk Access to Terminal: System Settings → Privacy & Security → Full Disk Access," >&2
  echo "    or enable manually: System Settings → General → Sharing → Remote Login" >&2
  exit 1
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
    # No --password given — prompt interactively (matches runbook).
    # sysadminctl cannot create a user with no password non-interactively;
    # -password "" fails with error 5402. Use -password - for interactive prompt.
    echo "  Enter a password for ${AUSER_NAME} (will be set; SSH key auth is also configured below):"
    sudo sysadminctl -addUser "${AUSER_NAME}" -password - -admin -home "/Users/${AUSER_NAME}"
  fi
  # sysadminctl can log errors to stderr but still exit 0 — verify with dscl.
  if ! dscl . -read "/Users/${AUSER_NAME}" UniqueID &>/dev/null; then
    echo "  ✗ ERROR: ${AUSER_NAME} was not created (sysadminctl failed)." >&2
    exit 1
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
# Embedded default — the control Mac's lzkmbp2016-micro-oracle key (also in client inventory).
# Override with --ssh-key <path> for a different key.
DEFAULT_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWRbHy2sWZLKET/74zvt0rZa4ET2zjes/SB+Y/3BmKp lzkmbp2016-micro-oracle"
if [[ -n "${SSH_KEY}" ]]; then
  if [[ ! -f "${SSH_KEY}" ]]; then
    echo "ERROR: SSH key file not found: ${SSH_KEY}" >&2
    exit 1
  fi
  PUB_KEY=$(cat "${SSH_KEY}")
else
  PUB_KEY="${DEFAULT_PUB_KEY}"
  echo "  Using embedded default key (lzkmbp2016-micro-oracle)"
fi

if [[ -z "${PUB_KEY}" ]]; then
  echo "ERROR: No SSH public key provided" >&2
  exit 1
fi

# Create .ssh directory (idempotent)
AUTH_KEYS="/Users/${AUSER_NAME}/.ssh/authorized_keys"
if [[ ! -d "/Users/${AUSER_NAME}/.ssh" ]]; then
  sudo mkdir -p "/Users/${AUSER_NAME}/.ssh"
  sudo chown "${AUSER_NAME}:staff" "/Users/${AUSER_NAME}/.ssh"
  sudo chmod 700 "/Users/${AUSER_NAME}/.ssh"
fi

# Check if key is already present
if sudo test -f "${AUTH_KEYS}" && sudo grep -qF "${PUB_KEY}" "${AUTH_KEYS}" 2>/dev/null; then
  echo "  ✓ SSH public key already in ${AUTH_KEYS}"
else
  # Append (preserves other keys), or create if file doesn't exist
  echo "${PUB_KEY}" | sudo tee -a "${AUTH_KEYS}" > /dev/null
  sudo chown "${AUSER_NAME}:staff" "${AUTH_KEYS}"
  sudo chmod 600 "${AUTH_KEYS}"
  echo "  ✓ SSH public key added to ${AUTH_KEYS}"
fi
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
