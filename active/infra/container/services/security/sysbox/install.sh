#!/bin/bash
# Install Sysbox on Debian/Ubuntu
# Reference: https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md

set -e

# Check for WSL2
if grep -qEi "(Microsoft|WSL)" /proc/version; then
    echo "WARNING: You appear to be running on WSL2."
    echo "Sysbox is NOT officially supported on WSL2 and requires specific kernel configurations."
    echo "It is highly recommended to use the standard Docker socket mount instead."
    read -p "Do you want to proceed anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Installing Sysbox..."

# 1. Clean up existing
sudo rm -rf /var/lib/sysbox
sudo rm -f /usr/bin/sysbox-runc /usr/bin/sysbox-fs /usr/bin/sysbox-mgr

# 2. Install dependencies
sudo apt-get update
sudo apt-get install -y jq wget

# 3. Download and Install Sysbox package directly (avoiding repo key issues)
SYSBOX_VERSION="0.6.7"
SYSBOX_DEB="sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb"
wget -O /tmp/${SYSBOX_DEB} https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}/${SYSBOX_DEB}

sudo apt-get install -y /tmp/${SYSBOX_DEB}
rm /tmp/${SYSBOX_DEB}

# 4. Verify installation
sudo systemctl status sysbox -n20 --no-pager

echo "Sysbox installed successfully!"
