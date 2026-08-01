# IP forwarding for Tailscale exit node support
#
# Enables net.inet.ip.forwarding=1 so the host can act as a Tailscale exit
# node (route traffic from other tailnet clients through this host's internet).
#
# nix-darwin has no boot.kernelSysctl option (unlike NixOS), so we manage
# /etc/sysctl.conf via activationScripts (root-only, idempotent) and apply
# the runtime sysctl at activation time.
#
# The Tailscale daemon's --advertise-exit-node flag is set separately via
# Ansible (runtime Tailscale state, not a system config).
{ pkgs, lib, config, ... }:
{
  options.infra.networking = {
    ipForwarding = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable IPv4 forwarding (net.inet.ip.forwarding=1) so this host can
        act as a Tailscale exit node. Writes to /etc/sysctl.conf for
        persistence and applies at activation time.
      '';
    };
  };

  config = lib.mkIf config.infra.networking.ipForwarding {
    system.activationScripts.ipForwarding.text = ''
      echo "enabling IP forwarding (net.inet.ip.forwarding=1)"

      # Runtime
      /usr/sbin/sysctl -w net.inet.ip.forwarding=1 > /dev/null

      # Persistent — idempotent: remove old entry, append fresh one
      if [ -f /etc/sysctl.conf ]; then
        /usr/bin/grep -v '^net.inet.ip.forwarding' /etc/sysctl.conf > /tmp/sysctl.conf.tmp || true
        mv /tmp/sysctl.conf.tmp /etc/sysctl.conf
      fi
      echo 'net.inet.ip.forwarding=1' >> /etc/sysctl.conf
    '';
  };
}
