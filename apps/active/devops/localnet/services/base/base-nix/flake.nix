{
  description = "Base Nix environment for sidecar containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.bash
          pkgs.shadow
          pkgs.gosu
          pkgs.coreutils
          pkgs.curl
          pkgs.wget
        ];
      };
    };
}
