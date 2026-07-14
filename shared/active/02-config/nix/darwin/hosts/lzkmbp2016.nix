# lzkmbp2016 — Intel x86_64 Mac
#
# Container runtime: OrbStack (x86 Mac, no Apple Container support)
# OS auto-install: OFF (runs OpenCore — automatic updates would break it)
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

  # Container runtime: OrbStack (x86 Mac, no Apple Container)
  infra.fleet.containerRuntime = "orbstack";
}
