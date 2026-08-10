# Nix binary cache settings (FR-8)
#
# Source: levonk-nix-config/modules/components/nix/cache.nix
# Updated for ADR-20260708001: Nix Cache Chain — Regional Multi-Layer with
# Parallel Racing. MacBooks use the nl region ncps cache (nixcache.nl.levonk.com)
# as the primary substituter, with cache.nixos.org as fallback.
#
# The nl ncps cache proxies to ncro which races Harmonia (local /nix/store on
# dtop202311), cache.nixos.org, cache.garnix.io, and nix-community.cachix.org
# in parallel, returning the fastest response.
#
# See: shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md
{ pkgs, ... }: {
  nix.settings = {
    # nixcache.nl.levonk.com is the nl region ncps cache (front door).
    # It caches NARs locally and races upstreams via ncro on cache miss.
    # Lower priority = preferred (Nix tries lower priority first).
    substituters = [
      "https://nixcache.nl.levonk.com?priority=30"
      "https://cache.nixos.org?priority=80"
    ];
    trusted-public-keys = [
      # ncps auto-generates a signing key with the cache hostname as the key name.
      # The public key is retrieved from the ncps /pubkey endpoint.
      "nixcache.nl.levonk.com:4lFFsosyMr06JYe2LllzAMTkuCvnIX5z4jiWgt2CaiA="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="
    ];
  };
}
