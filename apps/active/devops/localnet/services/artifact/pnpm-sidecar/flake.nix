{
  description = "PNPM sidecar environment";

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
          pkgs.nodePackages.pnpm
          pkgs.nodejs
        ];

        shellHook = ''
          export PNPM_HOME="/tmp/pnpm-home"
          mkdir -p "$PNPM_HOME"
          export PATH="$PNPM_HOME:$PATH"
        '';
      };
    };
}
