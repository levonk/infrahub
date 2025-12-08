{
  description = "Attic - Multi-tenant Nix Binary Cache Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    attic.url = "github:zhaofengli/attic";
    attic.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, attic }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      atticServer = attic.packages.${system}.attic-server;

      commonConfig = {
        Entrypoint = [ "${atticServer}/bin/atticd" ];
        ExposedPorts = {
          "8080/tcp" = {};
        };
        WorkingDir = "/data";
        Volumes = {
          "/data" = {};
        };
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          "ATTIC_SERVER_DATABASE_URL=sqlite:///data/server.db"
        ];
      };
    in
    {
      packages.${system} = {
        default = atticServer;

        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "attic-server";
          tag = "latest";
          created = "now";
          contents = [
            atticServer
            pkgs.bash
            pkgs.coreutils
            pkgs.cacert
            pkgs.netcat
          ];
          config = commonConfig;
        };

        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "attic-server-debug";
          tag = "latest";
          created = "now";
          contents = [
            atticServer
            # Shells
            pkgs.zsh
            pkgs.bashInteractive
            # Network
            pkgs.curl
            pkgs.wget
            pkgs.iproute2
            pkgs.dnsutils
            pkgs.netcat-gnu
            pkgs.tcpdump
            pkgs.socat
            pkgs.mtr
            pkgs.iputils
            # System
            pkgs.coreutils
            pkgs.procps
            pkgs.strace
            pkgs.lsof
            pkgs.htop
            pkgs.psmisc
            # File
            pkgs.vim
            pkgs.jq
            pkgs.ripgrep
            pkgs.findutils
            pkgs.file
            pkgs.tree
            pkgs.gnused
            pkgs.gnugrep
            pkgs.gawk
            pkgs.less
            pkgs.which
            # Misc
            pkgs.iana-etc
            pkgs.cacert
          ];
          config = commonConfig // {
            Env = commonConfig.Env ++ [
              "PATH=/bin:${pkgs.zsh}/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.procps}/bin:${pkgs.iproute2}/bin:${pkgs.jq}/bin:${pkgs.vim}/bin"
            ];
          };
        };
      };
    };
}
