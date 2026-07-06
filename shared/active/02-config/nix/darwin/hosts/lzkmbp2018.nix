# lzkmbp2018 — architecture TBD
#
# ponytail: containerRuntime unverified — check ssh auser@lzkmbp2018 'sw_vers; uname -m'
# and update if macOS 26+ ARM (set to "apple-container").
# Defaulting to "orbstack" until verified.
{ pkgs, ... }: {
  imports = [
    ../modules/system/defaults.nix
    ../modules/system/homebrew.nix
    ../modules/nix/settings.nix
    ../modules/nix/cache.nix
    ../modules/security/privacy-darwin.nix
    ../modules/fleet/default.nix
  ];

  # Nix-Darwin configuration
  system.stateVersion = 4;
  services.nix-daemon.enable = true;

  # Container runtime: default to orbstack until arch verified
  # ponytail: verify via ssh auser@lzkmbp2018 'sw_vers; uname -m'
  infra.fleet.containerRuntime = "orbstack";
}
