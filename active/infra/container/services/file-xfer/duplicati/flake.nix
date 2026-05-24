{
  description = "Duplicati Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation
      app = pkgs.duplicati;

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${app}/bin/duplicati-server" "--webservice-port=8200" "--webservice-interface=any" ];
        ExposedPorts = {
          "8200/tcp" = {};
        };
        Env = [
          "SERVICE_NAME=duplicati"
          "SERVICE_PORT=8200"
          "NODE_ENV=production"
          "XDG_CONFIG_HOME=/config"
          "XDG_DATA_HOME=/data"
        ];
        Volumes = {
          "/config" = {};
          "/data" = {};
          "/backups" = {};
          "/source" = {};
        };
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "duplicati";
          tag = "latest";
          contents = [
            app
            pkgs.mono
            pkgs.sqlite
            pkgs.cacert
            pkgs.bashInteractive
            pkgs.curl
            pkgs.coreutils
          ];
          extraCommands = ''
            mkdir -p config data backups source tmp
            mkdir -p var/run
          '';
          config = commonConfig;
        };

        # Debug Image
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "duplicati-debug";
          tag = "latest";
          contents = [
            app
            pkgs.mono
            pkgs.sqlite
            pkgs.cacert
            pkgs.zsh
            pkgs.bashInteractive
            pkgs.curl
            pkgs.wget
            pkgs.iproute2
            pkgs.dnsutils
            pkgs.netcat-gnu
            pkgs.procps
            pkgs.vim
            pkgs.coreutils
            pkgs.findutils
            pkgs.lsof
            pkgs.tree
            pkgs.less
          ];
          extraCommands = ''
            mkdir -p config data backups source tmp
            mkdir -p var/run
          '';
          config = commonConfig // {
            Env = commonConfig.Env ++ [
              "PATH=/bin:${pkgs.zsh}/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.procps}/bin"
            ];
          };
        };
      };
    };
}
