{
  description = "Alt-Sendme Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation
      app = pkgs.stdenv.mkDerivation {
        pname = "alt-sendme";
        version = "0.2.4";

        # We use the pre-downloaded deb content which we extracted to ./usr
        src = ./usr;

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
        ];

        buildInputs = [
          pkgs.stdenv.cc.cc.lib # libstdc++
          pkgs.glib
          pkgs.gtk3
          pkgs.webkitgtk_4_1
          pkgs.libsoup_3
        ];

        installPhase = ''
          mkdir -p $out/bin
          cp bin/alt-sendme $out/bin/
        '';
      };

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${app}/bin/alt-sendme" ];
        ExposedPorts = {
          "4444/tcp" = {}; # Default port based on docs/experience, need to verify
        };
        Env = [
          "SERVICE_NAME=alt-sendme"
          "NODE_ENV=production"
        ];
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image: Minimal
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "alt-sendme";
          tag = "latest";
          contents = [ app pkgs.cacert pkgs.glib pkgs.gtk3 pkgs.webkitgtk_4_1 pkgs.libsoup_3 ];
          config = commonConfig;
        };

        # Debug Image: App + Interactive Tools
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "alt-sendme-debug";
          tag = "latest";
          contents = [
            app
            pkgs.cacert
            pkgs.glib
            pkgs.gtk3
            pkgs.webkitgtk_4_1
            pkgs.libsoup_3
            pkgs.zsh
            pkgs.bashInteractive
            pkgs.curl
            pkgs.coreutils
            pkgs.procps
            pkgs.iproute2
            pkgs.netcat-gnu
            pkgs.vim
          ];
          config = commonConfig // {
            Env = commonConfig.Env ++ [
              "PATH=/bin:${pkgs.zsh}/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.procps}/bin"
            ];
          };
        };
      };
    };
}
