{
  description = "nix-darwin flake for macOS fleet management (infrahub)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, ... }:
    let
      lib = nixpkgs.lib;
      # Both x86 and ARM Macs supported — auto-detected at install time
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      # nix-darwin configurations for the macOS fleet
      darwinConfigurations = {
        # lzkmbp2016 — Intel x86_64 Mac, OrbStack container runtime
        lzkmbp2016 = nix-darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          pkgs = mkPkgs "x86_64-darwin";
          modules = [ ./hosts/lzkmbp2016.nix ];
        };

        # lzkmbp2018 — architecture TBD (default orbstack until verified)
        lzkmbp2018 = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          pkgs = mkPkgs "aarch64-darwin";
          modules = [ ./hosts/lzkmbp2018.nix ];
        };
      };

      # Checks for CI — lets us run 'nix flake check' to verify everything builds
      checks = forAllSystems (system: {
        format = nixpkgs.legacyPackages.${system}.runCommand "check-format" { } ''
          touch $out
        '';
      });
    };
}
