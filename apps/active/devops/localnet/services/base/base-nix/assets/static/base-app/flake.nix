{
  description = "Base Nix environment for containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.shadow
          pkgs.gosu
          pkgs.busybox
        ];
      };

      # Provide default package for compatibility
      defaultPackage.${system} = pkgs.mkShell {
        buildInputs = [
          pkgs.shadow
          pkgs.gosu
          pkgs.busybox
        ];
      };
    };
}
