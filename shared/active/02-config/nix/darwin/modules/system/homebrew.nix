# Homebrew module (FR-5)
#
# Source: levonk-nix-config/modules/system/darwin/homebrew.nix
# Changes from source:
#   - Personal cask list DROPPED (all fleet apps are in nixpkgs, installed via
#     environment.systemPackages in the fleet module)
#   - casks = [ ] — EMPTY fleet cask list
#
# Fleet apps installed via nix-darwin environment.systemPackages, not Homebrew
# casks (FR-5): orbstack, rustdesk, firefox-devedition-bin, raycast, cmux all
# available in nixpkgs.
#
# WARNING: onActivation.cleanup = "zap" removes ALL casks not in the list.
# Since the list is empty, ALL existing casks will be removed on first
# darwin-rebuild switch. If this is too aggressive for the first deploy,
# temporarily set cleanup = "none" and switch to "zap" after verification.
{ pkgs, ... }: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap"; # Dangerous: removes apps not in this list
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    taps = [
      "homebrew/bundle"
      "homebrew/services"
    ];

    brews = [ ];

    # Fleet cask list is EMPTY — all fleet apps are in nixpkgs (FR-5).
    # Homebrew is kept enabled for ad-hoc installs only.
    casks = [ ];
  };
}
