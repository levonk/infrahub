#!/usr/bin/env bash
set -euo pipefail

# bootstrap-linux-manual.sh
# Performs the minimal manual steps needed before Ansible can take over
# a fresh Linux machine (Debian/Ubuntu or RHEL/Rocky/Alma/Fedora).
#
# Run this ON the target Linux box (not the control machine).
# Must be run as a user with sudo access (the initial admin account).
#
# What it does:
#   1. Installs and enables OpenSSH Server (if not already)
#   2. Creates the auser admin user with sudo access
#   3. Grants auser passwordless sudo (NOPASSWD) — required for unattended Ansible
#   4. Adds the SSH public key for auser
#   5. Verifies SSH access and Python3 are working
#
# After this, run from the control Mac:
#   just ansible-deploy-bootstrap          # cloud server (OCI)
#   just ansible-bootstrap-ai-inference    # kckinai (GPU box)
#   Or the relevant playbook for your host type.
#
# Usage:
#   ./bootstrap-linux-manual.sh --ssh-key ~/.ssh/foo.pub                          # required — no embedded default
#   AUSER_PASSWORD="secret" ./bootstrap-linux-manual.sh --ssh-key ~/.ssh/foo.pub  # non-interactive with password

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
    --user)
      AUSER_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--ssh-key ~/.ssh/id_rsa.pub] [--password secret] [--user auser]"
      echo ""
      echo "Run ON the target Linux box. Creates the admin user and adds SSH key."
      echo "If --password is omitted, you will be prompted to enter a password interactively."
      echo "--ssh-key is required (no embedded default — client keys belong in client submodules)."
      echo "If --user is omitted, defaults to 'auser' (mirrors the macOS convention)."
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# --- Check we're on Linux ---
if [[ "$(uname)" != "Linux" ]]; then
  echo "ERROR: This script must be run on Linux (current: $(uname))" >&2
  exit 1
fi

# --- Detect distro family ---
# ponytail: 80% of the logic is identical across families. Only 3 things differ:
# package manager, SSH service name, and admin group name. One script with
# detection is smaller than two files duplicating 25 lines.
if command -v apt-get &>/dev/null; then
  DISTRO_FAMILY="debian"
  PKG_MGR="apt-get"
  SSH_SVC="ssh"
  ADMIN_GRP="sudo"
elif command -v dnf &>/dev/null; then
  DISTRO_FAMILY="redhat"
  PKG_MGR="dnf"
  SSH_SVC="sshd"
  ADMIN_GRP="wheel"
elif command -v yum &>/dev/null; then
  DISTRO_FAMILY="redhat"
  PKG_MGR="yum"
  SSH_SVC="sshd"
  ADMIN_GRP="wheel"
else
  echo "ERROR: Unsupported distro — no apt-get, dnf, or yum found." >&2
  exit 1
fi

# --- Check sudo access ---
if ! sudo -n true 2>/dev/null; then
  echo "This script needs sudo access. You'll be prompted for your password."
  sudo -v || { echo "ERROR: sudo access required" >&2; exit 1; }
fi

echo "=== Linux Manual Bootstrap ==="
echo "Host: $(hostname)"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -r)"
echo "Distro family: ${DISTRO_FAMILY}"
echo "Admin user: ${AUSER_NAME}"
echo ""

# --- Step 1: Install and enable SSH server ---
echo "[1/5] Installing and enabling OpenSSH Server..."
if systemctl is-active --quiet "${SSH_SVC}" 2>/dev/null; then
  echo "  ✓ SSH server already running (${SSH_SVC})"
else
  if ! command -v sshd &>/dev/null; then
    echo "  Installing openssh-server..."
    sudo "${PKG_MGR}" install -y openssh-server
  fi
  sudo systemctl enable --now "${SSH_SVC}"
  if systemctl is-active --quiet "${SSH_SVC}" 2>/dev/null; then
    echo "  ✓ SSH server started (${SSH_SVC})"
  else
    echo "  ✗ ERROR: SSH server failed to start." >&2
    exit 1
  fi
fi
echo ""

# --- Step 2: Create auser ---
echo "[2/5] Creating ${AUSER_NAME} admin user..."
if getent passwd "${AUSER_NAME}" &>/dev/null; then
  echo "  ✓ ${AUSER_NAME} already exists"
else
  sudo useradd -m -s /bin/bash "${AUSER_NAME}"
  if ! getent passwd "${AUSER_NAME}" &>/dev/null; then
    echo "  ✗ ERROR: ${AUSER_NAME} was not created (useradd failed)." >&2
    exit 1
  fi

  if [[ -n "${PASSWORD}" ]]; then
    echo "${AUSER_NAME}:${PASSWORD}" | sudo chpasswd
  else
    # Interactive prompt — chpasswd reads plaintext, hashes it appropriately.
    echo "  Enter a password for ${AUSER_NAME} (will be set; SSH key auth is also configured below):"
    sudo passwd "${AUSER_NAME}"
  fi
  echo "  ✓ Created ${AUSER_NAME}"
fi

# Ensure auser is in the admin group (idempotent)
if ! id -nG "${AUSER_NAME}" | grep -qw "${ADMIN_GRP}"; then
  sudo usermod -aG "${ADMIN_GRP}" "${AUSER_NAME}"
fi
echo "  ✓ ${AUSER_NAME} is in ${ADMIN_GRP} group"
echo ""

# --- Step 3: Grant auser passwordless sudo (NOPASSWD) ---
# Required for unattended Ansible runs. Without this, every become: true task
# would need --ask-become-pass, breaking automated configure/deploy runs.
# Mirrors the /etc/sudoers.d/<admin_user> entry created by the host-os-bootstrap
# Ansible role. We do it here (in the manual script) so Ansible has no barriers
# when it runs.
echo "[3/5] Granting ${AUSER_NAME} passwordless sudo (NOPASSWD)..."
SUDOERS_FILE="/etc/sudoers.d/${AUSER_NAME}"
SUDOERS_ENTRY="${AUSER_NAME} ALL=(ALL) NOPASSWD: ALL"
if sudo test -f "${SUDOERS_FILE}" && sudo grep -qxF "${SUDOERS_ENTRY}" "${SUDOERS_FILE}" 2>/dev/null; then
  echo "  ✓ ${SUDOERS_FILE} already has NOPASSWD entry"
else
  # Write the entry to a temp file, validate with visudo -cf, then install.
  # This avoids corrupting sudoers (a broken sudoers file can lock out all sudo).
  TMP_SUDOERS=$(mktemp)
  echo "${SUDOERS_ENTRY}" > "${TMP_SUDOERS}"
  if sudo visudo -cf "${TMP_SUDOERS}" >/dev/null 2>&1; then
    sudo install -m 0440 -o root -g root "${TMP_SUDOERS}" "${SUDOERS_FILE}"
    echo "  ✓ Created ${SUDOERS_FILE} with NOPASSWD entry (validated by visudo)"
  else
    echo "  ✗ ERROR: visudo validation failed — sudoers file NOT installed" >&2
    rm -f "${TMP_SUDOERS}"
    exit 1
  fi
  rm -f "${TMP_SUDOERS}"
fi
echo ""

# --- Step 4: Add SSH public key ---
echo "[4/5] Adding SSH public key for ${AUSER_NAME}..."

# --ssh-key is REQUIRED — no embedded default.
# Client-specific keys must not be hardcoded in shared/ (ADR-20260624001).
if [[ -z "${SSH_KEY}" ]]; then
  echo "ERROR: --ssh-key <path> is required (no embedded default in shared/)" >&2
  echo "       Client-specific keys belong in the client submodule (e.g. levonk/)" >&2
  exit 1
fi
if [[ ! -f "${SSH_KEY}" ]]; then
  echo "ERROR: SSH key file not found: ${SSH_KEY}" >&2
  exit 1
fi
PUB_KEY=$(cat "${SSH_KEY}")

if [[ -z "${PUB_KEY}" ]]; then
  echo "ERROR: No SSH public key provided" >&2
  exit 1
fi

AUSER_HOME=$(getent passwd "${AUSER_NAME}" | cut -d: -f6)
AUTH_KEYS="${AUSER_HOME}/.ssh/authorized_keys"

# Create .ssh directory (idempotent)
if [[ ! -d "${AUSER_HOME}/.ssh" ]]; then
  sudo mkdir -p "${AUSER_HOME}/.ssh"
  sudo chown "${AUSER_NAME}:${AUSER_NAME}" "${AUSER_HOME}/.ssh"
  sudo chmod 700 "${AUSER_HOME}/.ssh"
fi

# Check if key is already present
if sudo test -f "${AUTH_KEYS}" && sudo grep -qF "${PUB_KEY}" "${AUTH_KEYS}" 2>/dev/null; then
  echo "  ✓ SSH public key already in ${AUTH_KEYS}"
else
  echo "${PUB_KEY}" | sudo tee -a "${AUTH_KEYS}" > /dev/null
  sudo chown "${AUSER_NAME}:${AUSER_NAME}" "${AUTH_KEYS}"
  sudo chmod 600 "${AUTH_KEYS}"
  echo "  ✓ SSH public key added to ${AUTH_KEYS}"
fi
echo ""

# --- Step 5: Verify ---
echo "[5/5] Verification..."
echo "  User: $(getent passwd "${AUSER_NAME}" | cut -d: -f1) (UID: $(id -u "${AUSER_NAME}"))"
echo "  Admin group: $(id -nG "${AUSER_NAME}" | tr ' ' '\n' | grep -x "${ADMIN_GRP}" || echo "NOT in ${ADMIN_GRP}")"
echo "  Passwordless sudo: $(sudo -u "${AUSER_NAME}" sudo -n true 2>/dev/null && echo 'working' || echo 'NOT working')"
echo "  SSH server: $(systemctl is-active "${SSH_SVC}")"
echo "  SSH key: $(sudo cat "${AUTH_KEYS}" | head -c 40)..."

# Python3 check — Ansible needs it on the target. Most Linux distros ship it,
# but minimal/server installs may not. Surface the gap early rather than letting
# Ansible fail with a cryptic "module stdout" error.
if command -v python3 &>/dev/null; then
  echo "  Python3: $(python3 --version 2>&1)"
else
  echo "  Python3: NOT FOUND — Ansible will fail." >&2
  echo "    Install it: sudo ${PKG_MGR} install -y python3" >&2
  exit 1
fi

# Get this machine's IP for the hint
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<linux-ip>")
TS_HOST=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

echo ""
echo "=== Done! ==="
if [[ -n "${TS_HOST}" ]]; then
  echo "From the control Mac, verify SSH access:"
  echo "  ssh ${AUSER_NAME}@${TS_HOST}"
else
  echo "From the control Mac, verify SSH access:"
  echo "  ssh ${AUSER_NAME}@${LAN_IP}"
fi
echo ""
echo "Then run the relevant Ansible bootstrap:"
echo "  just ansible-deploy-bootstrap          # cloud server (OCI)"
echo "  just ansible-bootstrap-ai-inference    # kckinai (GPU box)"
echo "  Or the playbook matching your host type."
