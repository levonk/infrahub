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
# `!include nix.custom.conf`). nix-darwin ALSO writes /etc/nix/nix.conf
# via `nix.settings`. This creates a conflict: whichever runs last wins.
#
# Resolution:
#   1. nix-darwin's `nix.settings` is the declarative source of truth.
#      `darwin-rebuild switch` writes /etc/nix/nix.conf from these settings.
#   2. Determinate Nix's /etc/nix/nix.conf is overwritten on first
#      `darwin-rebuild switch`. This is expected and acceptable.
#   3. Any custom settings not covered by `nix.settings.*` should go in
#      /etc/nix/nix.custom.conf (Determinate's include file), which
#      nix-darwin does NOT manage.
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
{ pkgs, ... }: {
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
}
