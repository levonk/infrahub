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
