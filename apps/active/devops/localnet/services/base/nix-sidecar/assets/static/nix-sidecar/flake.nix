{
  description = "A flake for nix-sidecar development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: {
    devShell.x86_64-linux =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
      pkgs.mkShell {
        packages = with pkgs; [
          shadow
          gosu
          busybox
          supercronic
          cacert
        ];

        shellHook = ''
          echo "Entering nix-sidecar development environment"
        '';
      };

    # Provide default package for compatibility
    defaultPackage.x86_64-linux =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      pkgs.mkShell {
        packages = with pkgs; [
          shadow
          gosu
          busybox
          supercronic
          cacert
        ];
      };

    # Default app for running the shell
    apps.x86_64-linux.default = {
      type = "app";
      program = "${nixpkgs.legacyPackages.x86_64-linux.bash}/bin/bash";
    };
  };
}
