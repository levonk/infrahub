# Nix binary cache settings (FR-8)
#
# Updated for ADR-20260708001: Nix Cache Chain — Regional Multi-Layer with
# Parallel Racing. This module provides generic upstream substituters only.
# Client-specific substituters (e.g. a regional ncps cache) should be added
# in the client-specific nix-darwin configuration.
#
# cache.garnix.io removed after Garnix shutdown (July 15 2026), per
# ADR-20260708001 supplement.
#
# Determinate Nix coexistence: nix.settings.* is NOT written to
# /etc/nix/nix.conf when nix.enable = false. The substituters and
# trusted-public-keys are written to /etc/nix/nix.custom.conf via
# environment.etc, which Determinate Nix includes via `!include`.
#
# See: shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md
{ pkgs, ... }: {
  # nix.settings is kept for documentation and non-Determinate hosts.
  # On Determinate Nix hosts, the environment.etc below is what actually
  # reaches the active Nix config.
  nix.settings = {
    # Generic upstream substituters only.
    # Client-specific ncps caches and their public keys should be added
    # in the client-specific nix-darwin config.
    # Lower priority = preferred (Nix tries lower priority first).
    substituters = [
      "https://cache.nixos.org?priority=80"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="
    ];
  };

  # Determinate Nix: write substituters to nix.custom.conf (included by
  # Determinate's /etc/nix/nix.conf via `!include nix.custom.conf`).
  # This is the mechanism that actually reaches the active Nix config.
  environment.etc."nix/nix.custom.conf".text = ''
    # Managed by nix-darwin — DO NOT EDIT MANUALLY
    # This file is included by Determinate Nix's /etc/nix/nix.conf via:
    #   !include nix.custom.conf
    #
    # Substituters and trusted-public-keys from nix.settings are written
    # here because nix.enable = false prevents nix-darwin from writing
    # /etc/nix/nix.conf directly.

    # Experimental features (in case Determinate's base config doesn't set them)
    experimental-features = nix-command flakes

    # Keep outputs and derivations for remote dev
    keep-outputs = true
    keep-derivations = true

    # Flake settings
    accept-flake-config = true
    auto-optimise-store = true

    # Generic upstream substituters (fallback).
    # Client-specific ncps caches are prepended by the client cache module.
    # Lower priority = preferred (Nix tries lower priority first).
    substituters = https://cache.nixos.org?priority=80
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q=
  '';
}
