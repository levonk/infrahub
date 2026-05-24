{
  description = "Iron-Proxy - Daemonless Nix Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";

  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {

          # Standalone service packages
          packages = with pkgs; [
            # Core utilities
            shadow
            gosu
            busybox



          ];


          shellHook = ''
            echo "🛠️  Iron-Proxy Nix Environment Loaded"
            echo "   - Service: "
            echo "   - Mode: Daemonless Nix"


          '';
        };
      });
}
