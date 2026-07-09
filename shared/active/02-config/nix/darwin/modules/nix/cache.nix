# Nix binary cache settings (FR-8)
#
# Source: levonk-nix-config/modules/components/nix/cache.nix
# No changes from source — byte-identical content.
#
# NOTE: The local Harmonia substituter TODO below will be resolved by
# ADR-20260708001 (Nix Cache Chain — Regional Multi-Layer with Parallel Racing).
# Once deployed, this module will be updated to point to the local Harmonia
# instance (127.0.0.1:5000) and the regional ncps instance.
# See: shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md
{ pkgs, ... }: {
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      # "https://harmonia.local" # TODO: Add local cache when setup
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}
