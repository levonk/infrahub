{
  description = "NX sidecar environment - Centralized NX build cache";

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
          export PNPM_HOME="/home/cuser/.local/share/pnpm"
          export NX_CACHE_DIRECTORY="/var/cache/nx-cache"
          mkdir -p "$PNPM_HOME" "$NX_CACHE_DIRECTORY"
          export PATH="$PNPM_HOME:$PATH"
        '';
      };
    };
}
