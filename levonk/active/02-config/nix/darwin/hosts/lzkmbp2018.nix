# lzkmbp2018 — Intel x86_64 Mac
#
# Container runtime: OrbStack (x86 Mac, no Apple Container support)
{ pkgs, ... }: {
  imports = [
    ../modules/system/defaults.nix
    ../modules/system/homebrew.nix
    ../modules/system/zsh.nix
    ../modules/nix/settings.nix
    ../modules/nix/cache.nix
    ../modules/security/privacy-darwin.nix
    ../modules/fleet/default.nix
    ../modules/networking/default.nix
  ];

  # Nix-Darwin configuration
  system.stateVersion = 4;
  # system.primaryUser: required by nix-darwin for user-level defaults
  # (dock, finder, CustomUserPreferences, homebrew, etc.)
  system.primaryUser = "micro";

  # Container runtime: default to orbstack until arch verified
  # ponytail: verify via ssh auser@lzkmbp2018 'sw_vers; uname -m'
  infra.fleet.containerRuntime = "orbstack";

  # Enable IP forwarding so this host can act as a Tailscale exit node
  infra.networking.ipForwarding = true;
}
