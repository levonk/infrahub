{
  description = "nix-darwin flake for levonk macOS fleet (client-specific host configs)";

  inputs = {
    # Shared inputs — must match shared/active/02-config/nix/darwin/flake.nix
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

      # Shared modules from shared/active/02-config/nix/darwin/modules/
      # Referenced by relative path from this flake.
      sharedModulesPath = ../../../../../shared/active/02-config/nix/darwin/modules;
      sharedModules = [
        "${sharedModulesPath}/system/defaults.nix"
        "${sharedModulesPath}/system/homebrew.nix"
        "${sharedModulesPath}/system/zsh.nix"
        "${sharedModulesPath}/nix/settings.nix"
        "${sharedModulesPath}/nix/cache.nix"
        "${sharedModulesPath}/security/privacy-darwin.nix"
        "${sharedModulesPath}/fleet/default.nix"
        "${sharedModulesPath}/networking/default.nix"
      ];
    in
    {
      # nix-darwin configurations for the levonk macOS fleet
      darwinConfigurations = {
        # lzkmbp2016 — Intel x86_64 Mac, OrbStack container runtime
        lzkmbp2016 = (darwinFor "x86_64-darwin").lib.darwinSystem {
          system = "x86_64-darwin";
          pkgs = mkPkgs "x86_64-darwin";
          modules = sharedModules ++ [ ./hosts/lzkmbp2016.nix ];
        };

        # lzkmbp2018 — Intel x86_64 Mac, OrbStack container runtime
        lzkmbp2018 = (darwinFor "x86_64-darwin").lib.darwinSystem {
          system = "x86_64-darwin";
          pkgs = mkPkgs "x86_64-darwin";
          modules = sharedModules ++ [ ./hosts/lzkmbp2018.nix ];
        };
      };
    };
}
