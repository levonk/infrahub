# Nix settings (FR-8)
#
# Source: levonk-nix-config/modules/components/nix/settings.nix
# Changes from source:
#   - Added Determinate Nix coexistence documentation and settings
#
# Determinate Nix coexistence (ADR-202607070001 supplement):
#
# This machine uses Determinate Nix (the installer that writes
# /etc/nix/nix.conf with a "DETERMINATE NIX CONFIG" header and
# `!include nix.custom.conf`). With nix.enable = false, nix-darwin
# does NOT write /etc/nix/nix.conf — Determinate Nix owns it.
#
# Resolution:
#   1. nix.enable = false: nix-darwin does not manage the Nix
#      installation (daemon, binaries, auto-updater). This avoids
#      the "Determinate detected, aborting activation" error.
#   2. nix.settings.*: evaluated by nix-darwin but NOT written to
#      /etc/nix/nix.conf when nix.enable = false. These are still
#      useful for documentation and for non-Determinate hosts.
#   3. environment.etc."nix/nix.custom.conf": nix-darwin writes this
#      file, which Determinate Nix includes via `!include nix.custom.conf`
#      in /etc/nix/nix.conf. This is how substituters and trusted-public-keys
#      reach the active Nix config on Determinate Nix hosts.
#   4. The Determinate Nix auto-updater continues to work — it updates
#      the nix binaries, not nix.conf.
#
# If you need to re-run the Determinate installer (e.g., after a major
# Nix version upgrade), use:
#   curl --proto '=https' --tlsv1.2 -sSf -L \
#     https://install.determinate.systems/nix | sh -s -- install \
#     --no-modify-nix-conf
# The --no-modify-nix-conf flag prevents Determinate from overwriting
# nix-darwin's /etc/nix/nix.conf.
{ pkgs, lib, ... }: {
  # nix.enable is NOT set here. Each host must set it explicitly:
  #   - Determinate Nix hosts: nix.enable = false (Determinate owns nix.conf)
  #   - Vanilla Nix hosts: nix.enable = true (nix-darwin owns nix.conf)
  # This avoids module priority conflicts between the shared default
  # and host-level overrides.

  nix.settings = {
    # For Remote Dev
    keep-outputs = true;
    keep-derivations = true;

    # Experimental Features
    experimental-features = [ "nix-command" "flakes" ];

    # Flake registry settings
    flake-registry = "https://github.com/NixOS/flake-registry/raw/master/flake-registry.json";

    # Accept flake registry
    accept-flake-config = true;

    auto-optimise-store = true;

    # Determinate Nix coexistence: these settings are written to
    # /etc/nix/nix.conf by darwin-rebuild switch, overwriting Determinate's
    # version. The values below match Determinate's defaults to minimize
    # disruption on the first switch.
    always-allow-substitutes = true;
    max-jobs = "auto";
  };

  # Determinate Nix coexistence: nix.settings.* is NOT written to
  # /etc/nix/nix.conf when nix.enable = false. The cache.nix module writes
  # substituters and trusted-public-keys to /etc/nix/nix.custom.conf via
  # environment.etc, which Determinate Nix includes via `!include`.
  # See: modules/nix/cache.nix for the environment.etc declaration.
}
