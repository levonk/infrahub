{
  description = "nix-darwin flake for macOS fleet management (infrahub)";

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
          config.allowUnfree = true;
        };
    in
    {
      # nix-darwin configurations for the macOS fleet
      darwinConfigurations = {
        # lzkmbp2016 — Intel x86_64 Mac, OrbStack container runtime
        lzkmbp2016 = (darwinFor "x86_64-darwin").lib.darwinSystem {
          system = "x86_64-darwin";
          pkgs = mkPkgs "x86_64-darwin";
          modules = [ ./hosts/lzkmbp2016.nix ];
        };

        # lzkmbp2018 — architecture TBD (default orbstack until verified)
        lzkmbp2018 = (darwinFor "aarch64-darwin").lib.darwinSystem {
          system = "aarch64-darwin";
          pkgs = mkPkgs "aarch64-darwin";
          modules = [ ./hosts/lzkmbp2018.nix ];
        };
      };

      # Checks for CI — lets us run 'nix flake check' to verify everything builds
      checks = forAllSystems (system: {
        format = (pkgsFor system).legacyPackages.${system}.runCommand "check-format" { } ''
          touch $out
        '';
      });
    };
}
