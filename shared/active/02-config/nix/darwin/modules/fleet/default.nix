# Fleet module (FR-4, FR-5)
#
# Defines:
#   - infra.fleet.containerRuntime option (enum: "orbstack" | "apple-container")
#   - users.users.auser admin account
#   - environment.systemPackages with fleet apps (all from nixpkgs)
#
# No HM (NFR-5). No secrets in flake (NFR-2) — auser password stays
# vault-owned, managed by Ansible bootstrap.
{ pkgs, lib, config, ... }:
let
  cfg = config.infra.fleet;
in
{
  options.infra.fleet = {
    containerRuntime = lib.mkOption {
      type = lib.types.enum [ "orbstack" "apple-container" ];
      default = "orbstack";
      description = ''
        Container runtime to use on this host.
        - "orbstack": OrbStack (works on x86 + ARM, third-party)
        - "apple-container": Apple Container (macOS 26+ ARM only, native)
      '';
    };
  };

  config = {
    # Admin user account — replaces imperative sysadminctl/dscl creation
    # Password stays vault-owned (Ansible bootstrap sets it), not managed here.
    users.users.auser = {
      name = "auser";
      home = "/Users/auser";
      # nix-darwin: add to admin group for sudo access
      # The 'admin' group is the macOS admin group (equivalent to wheel on Linux)
    };

    # Fleet apps — all from nixpkgs (FR-5: prefer Nix packages over casks)
    # orbstack and rustdesk moved from Homebrew casks to Nix packages.
    environment.systemPackages = with pkgs;
      [
        git
        zsh
        tailscale
        netbird
        cmux
        firefox-devedition-bin
        raycast
        rustdesk
      ]
      ++ lib.optional (cfg.containerRuntime == "orbstack") orbstack;
  };
}
