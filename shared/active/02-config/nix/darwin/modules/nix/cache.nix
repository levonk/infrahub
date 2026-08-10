# Nix binary cache settings (FR-8)
#
# Updated for ADR-20260708001: Nix Cache Chain — Regional Multi-Layer with
# Parallel Racing. This module provides generic upstream substituters only.
# Client-specific substituters (e.g. a regional ncps cache) should be added
# in the client-specific nix-darwin configuration.
#
# See: shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md
{ pkgs, ... }: {
  nix.settings = {
    # Generic upstream substituters only.
    # Client-specific ncps caches and their public keys should be added
    # in the client-specific nix-darwin config.
    # Lower priority = preferred (Nix tries lower priority first).
    substituters = [
      "https://cache.nixos.org?priority=80"
      "https://cache.garnix.io?priority=90"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="
      "cache.garnix.io:fh5K0G1Y2GEChdVttdRpZp+3rhp6ZjlZsLgZ5gJ5m5U="
    ];
  };
}
