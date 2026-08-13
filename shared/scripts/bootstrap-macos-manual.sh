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
#   3. Grants auser passwordless sudo (NOPASSWD) — required for unattended Ansible
#   4. Adds the SSH public key for auser
#   5. Verifies SSH access is working
#   6. Checks Apple ID / App Store sign-in for the current (GUI) user
#
# Why step 6 exists — distributed configuration for Xcode:
#   Xcode is installed by the Ansible `macos-xcode` role using `mas` (Mac App
#   Store CLI). `mas` is installed by nix-darwin via Ansible (not this script),
#   and `mas` requires an Apple ID signed in to the App Store. However, `mas
#   signin` is disabled on macOS 10.13+ (Apple removed the private API), and
#   2FA requires GUI interaction — so there is no way to automate the sign-in
#   via Ansible or vault credentials. The sign-in must happen manually via the
#   GUI (System Settings → Apple ID or the App Store app).
#
#   App Store sign-in is PER-MACOS-USER, not system-wide. Ansible connects as
#   `auser` (the SSH service account), but `auser` is a headless admin with no
#   GUI session. Instead, the Ansible xcode role checks ALL human users (UID
#   >= 501) in priority order — auser, GUI user, then all others — and uses
#   the first one signed in to the App Store. So ANY user being signed in is
#   sufficient — that's what this step checks.
#
#   Xcode installs to /Applications/ and is available to ALL users on the Mac
#   regardless of which user installed it. Only the sign-in is per-user; the
#   installed app is shared. Other users may get a one-time App Store password
#   prompt when they first launch Xcode (normal macOS behavior for App Store
#   apps installed by a different Apple ID).
#
#   This is why the configuration is distributed across two phases:
#     Phase 1 (this script, target Mac, human at keyboard):
#       - SSH, auser, sudo, SSH key (automated by this script)
#       - Apple ID / App Store sign-in for the GUI user (manual, GUI only)
#     Phase 2 (Ansible, control Mac, unattended):
#       - nix-darwin apply (installs mas and other fleet tools)
#       - mas installs Xcode as the GUI user (unattended, ~12GB download)
#       - License accept + xcode-select (as root, unattended)
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
      echo "If --password is omitted, you will be prompted to enter a password interactively."
      echo "If --ssh-key is omitted, uses the embedded default key (lzkmbp2016-micro-oracle)."
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
echo "[1/6] Enabling Remote Login (SSH server)..."
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
echo "[2/6] Creating ${AUSER_NAME} admin user..."
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

# --- Step 3: Grant auser passwordless sudo (NOPASSWD) ---
# Required for unattended Ansible runs. Without this, every become: true task
# would need --ask-become-pass, breaking automated configure/os-update runs.
# Mirrors the /etc/sudoers.d/<admin_user> entry created by bootstrap-macos-host.yml.
# We do it here (in the manual script) so Ansible has no barriers when it runs.
echo "[3/6] Granting ${AUSER_NAME} passwordless sudo (NOPASSWD)..."
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
    sudo install -m 0440 -o root -g wheel "${TMP_SUDOERS}" "${SUDOERS_FILE}"
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
echo "[4/6] Adding SSH public key for ${AUSER_NAME}..."

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

# --- Step 5: Verify ---
echo "[5/6] Verification..."
echo "  User: $(dscl . -read "/Users/${AUSER_NAME}" UniqueID 2>/dev/null | awk '{print $2}')"
echo "  Admin group: $(sudo dseditgroup -o checkmember -m "${AUSER_NAME}" admin 2>/dev/null || echo 'NOT in admin group')"
echo "  SSH key: $(sudo cat "/Users/${AUSER_NAME}/.ssh/authorized_keys" | head -c 40)..."
echo "  Passwordless sudo: $(sudo -u "${AUSER_NAME}" sudo -n true 2>/dev/null && echo 'working' || echo 'NOT working')"

# --- Step 6: Apple ID / App Store sign-in check ---
# mas (Mac App Store CLI) is installed later by nix-darwin via Ansible's
# configure-macos-host playbook, so we can't use `mas account` here. Instead,
# check each user's iCloud account state (MobileMeAccounts defaults) as a
# proxy — if an Apple ID is signed in to iCloud, the App Store is signed in
# too with the same account.
#
# We check ALL human users (UID >= 501) in priority order:
#   1. auser (the Ansible service account — unlikely but check anyway)
#   2. GUI user (stat -f%Su /dev/console — whoever is logged in to the GUI)
#   3. All other human users
# The first user found with an App Store sign-in is the one Ansible will use
# to run `mas install`. This matches the Ansible xcode role's behavior.
#
# App Store sign-in is PER-MACOS-USER. Ansible connects as `auser` (headless
# service account), but the xcode role runs `mas` as whichever user is signed
# in. Xcode installs to /Applications/ and is available to ALL users. Other
# users may get a one-time App Store password prompt when they first launch
# Xcode (normal macOS behavior for App Store apps installed by a different
# Apple ID).
#
# No pause: the user signs in during the natural break between this script
# (run on the target Mac) and the Ansible run (kicked off from the control Mac).
GUI_USER="$(stat -f%Su /dev/console 2>/dev/null || echo "${USER}")"

# Build the user check list: auser first, then GUI user, then all other human users.
# Human users have UID >= 501 on macOS (system accounts are < 501).
ALL_HUMAN_USERS="$(dscl . -list /Users UniqueID 2>/dev/null | awk '$2 >= 501 {print $1}')"
CHECK_USERS=""
# 1. auser first
if echo "${ALL_HUMAN_USERS}" | grep -qx "${AUSER_NAME}"; then
  CHECK_USERS="${AUSER_NAME}"
fi
# 2. GUI user (if different from auser)
if [[ -n "${GUI_USER}" && "${GUI_USER}" != "${AUSER_NAME}" ]] && echo "${ALL_HUMAN_USERS}" | grep -qx "${GUI_USER}"; then
  CHECK_USERS="${CHECK_USERS}${CHECK_USERS:+ }${GUI_USER}"
fi
# 3. All other human users (excluding auser and GUI user, already added)
for U in ${ALL_HUMAN_USERS}; do
  if [[ "${U}" != "${AUSER_NAME}" && "${U}" != "${GUI_USER}" ]]; then
    CHECK_USERS="${CHECK_USERS}${CHECK_USERS:+ }${U}"
  fi
done

echo ""
echo "[6/6] Checking Apple ID / App Store sign-in across all users..."
echo "  Users to check: ${CHECK_USERS:-none found}"

SIGNED_IN_USER=""
SIGNED_IN_APPLE_ID=""
for U in ${CHECK_USERS}; do
  if sudo -u "${U}" defaults read MobileMeAccounts 2>/dev/null | grep -q "AccountDSID"; then
    SIGNED_IN_APPLE_ID="$(sudo -u "${U}" defaults read MobileMeAccounts 2>/dev/null | grep 'AccountDescription' | head -1 | sed 's/.*= "\(.*\)";/\1/')"
    SIGNED_IN_USER="${U}"
    echo "  ✓ Apple ID signed in: ${SIGNED_IN_APPLE_ID} (user: ${U})"
    break
  else
    echo "  · ${U}: not signed in"
  fi
done

if [[ -n "${SIGNED_IN_USER}" ]]; then
  echo ""
  echo "  Ansible will use '${SIGNED_IN_USER}' to run mas and install Xcode."
  echo "  Xcode will be in /Applications/ — available to all users."
else
  echo ""
  echo "  ⚠ No users on this Mac are signed in to the App Store."
  echo ""
  echo "  Xcode is installed via \`mas\` (Mac App Store CLI) by the Ansible"
  echo "  macos-xcode role. mas requires an Apple ID signed in to the App Store."
  echo "  \`mas signin\` is disabled on macOS 10.13+ and 2FA requires GUI"
  echo "  interaction, so this cannot be automated — sign in manually."
  echo ""
  echo "  App Store sign-in is PER-MACOS-USER. Ansible will check all users"
  echo "  and use whichever one is signed in. Sign in as ANY user — it"
  echo "  doesn't matter which one. Xcode installs to /Applications/ and is"
  echo "  shared with all users. Other users may get a one-time App Store"
  echo "  password prompt when they first launch Xcode."
  echo ""
  echo "  Opening System Settings → Apple ID as ${GUI_USER}..."

  # Open the Apple ID settings pane in System Settings.
  # x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane works on
  # macOS 13+ (Ventura), 15+ (Sequoia), and 26+ (Tahoe).
  # Run `open` as the GUI user so it opens in their GUI session, not root's.
  if sudo -u "${GUI_USER}" open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane" 2>/dev/null; then
    echo "  ✓ Opened System Settings → Apple ID"
  else
    echo "  ✗ Could not open System Settings automatically."
    echo "    Open manually: System Settings → Apple ID (top-left corner)"
  fi

  echo ""
  echo "  Sign in with any Apple ID, then run Ansible from the control Mac."
  echo "  Ansible will detect the signed-in user automatically. ⚠️"
fi

# Get this machine's Tailscale hostname or LAN IP for the hint
TS_HOST=$(tailscale status --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
if [[ -n "${TS_HOST}" ]]; then
  echo ""
  echo "=== Done! ==="
  echo "From the control Mac, verify SSH access:"
  echo "  ssh ${AUSER_NAME}@${TS_HOST}"
  echo ""
  echo "Before running Ansible, make sure:"
  echo "  1. At least one user on this Mac is signed in to the App Store"
  echo "     (System Settings → Apple ID) — required for mas to install Xcode"
  echo "  2. No inventory changes needed — Ansible auto-detects signed-in users"
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
  echo "Before running Ansible, make sure:"
  echo "  1. At least one user on this Mac is signed in to the App Store"
  echo "     (System Settings → Apple ID) — required for mas to install Xcode"
  echo "  2. No inventory changes needed — Ansible auto-detects signed-in users"
  echo ""
  echo "Then run the Ansible bootstrap:"
  echo "  just ansible-bootstrap-macos"
fi
