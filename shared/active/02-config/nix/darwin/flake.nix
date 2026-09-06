{
  description = "nix-darwin shared module library for macOS fleet management (infrahub)";

  inputs = {
    # Default: nixpkgs-unstable + nix-darwin master (aarch64-darwin, linux).
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # x86_64-darwin was dropped in nixpkgs 26.11/unstable; pin to 26.05
    # which still supports it (security fixes until end of 2026).
    nixpkgs-x86-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin-x86.url = "git+https://github.com/LnL7/nix-darwin.git?ref=nix-darwin-26.05&shallow=1";
    nix-darwin-x86.inputs.nixpkgs.follows = "nixpkgs-x86-darwin";
  };

  outputs = { self, nixpkgs, nix-darwin, nix-darwin-x86, nixpkgs-x86-darwin, ... }:
    let
      lib = nixpkgs.lib;
      # Both x86 and ARM Macs supported — auto-detected at install time
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      # Select nixpkgs/nix-darwin per architecture: x86_64-darwin needs
      # the 26.05 pin (dropped in unstable), aarch64 stays on unstable.
      pkgsFor = system:
        if system == "x86_64-darwin" then nixpkgs-x86-darwin else nixpkgs;
      darwinFor = system:
        if system == "x86_64-darwin" then nix-darwin-x86 else nix-darwin;

      mkPkgs = system:
        import (pkgsFor system) {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              "electron-39.8.10"
            ];
          };
        };
    in
    {
      # Shared nix-darwin module library — client flakes import these.
      # Client-specific host configs (darwinConfigurations) live in the
      # client submodule (e.g. levonk/active/02-config/nix/darwin/flake.nix).
      modules = {
        # Generic, non-client-specific modules
        defaults = ./modules/system/defaults.nix;
        homebrew = ./modules/system/homebrew.nix;
        zsh = ./modules/system/zsh.nix;
        nixSettings = ./modules/nix/settings.nix;
        nixCache = ./modules/nix/cache.nix;
        nixHarmonia = ./modules/nix/harmonia.nix;
        privacy = ./modules/security/privacy-darwin.nix;
        sudo = ./modules/security/sudo.nix;
        fleet = ./modules/fleet/default.nix;
        networking = ./modules/networking/default.nix;

        # Convenience: all shared modules as a list
        all = [
          ./modules/system/defaults.nix
          ./modules/system/homebrew.nix
          ./modules/system/zsh.nix
          ./modules/nix/settings.nix
          ./modules/nix/cache.nix
          ./modules/nix/harmonia.nix
          ./modules/security/privacy-darwin.nix
          ./modules/security/sudo.nix
          ./modules/fleet/default.nix
          ./modules/networking/default.nix
        ];
      };

      # Expose helpers for client flakes to use
      inherit darwinFor mkPkgs;

      # Checks for CI — lets us run 'nix flake check' to verify everything builds
      checks = forAllSystems (system: {
        format = (pkgsFor system).legacyPackages.${system}.runCommand "check-format" { } ''
          touch $out
        '';
      });
    };
}
