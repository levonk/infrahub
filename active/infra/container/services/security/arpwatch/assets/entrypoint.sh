#!/bin/sh
# shellcheck shell=sh

# Note: On Windows/WSL2, this container must be run in a Linux VM on the network.
# Windows will not share its NIC devices/wifi with Docker in WSL2 in a way that allows promiscuous mode monitoring.

set -e -u -o pipefail

# Ensure the data file exists
if [ ! -f /var/lib/arpwatch/arp.dat ]; then
    echo "Creating empty arp.dat"
    touch /var/lib/arpwatch/arp.dat
fi

echo "Starting arpwatch on interface $INTERFACE"
# -d: Debug mode (don't fork)
# -N: Don't report new stations (optional, but default is to report)
# -i: Interface
# -f: Data file
exec arpwatch -d -i "$INTERFACE" -f /var/lib/arpwatch/arp.dat
