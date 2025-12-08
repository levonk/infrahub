{
  description = "NCPS - Nix Cache Proxy Server Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ncps.url = "github:kalbasit/ncps";
    ncps.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ncps }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ncpsPkg = ncps.packages.${system}.default;

      commonConfig = {
        Entrypoint = [ "${ncpsPkg}/bin/ncps" ];
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        ExposedPorts = {
          "8080/tcp" = {};
        };
        WorkingDir = "/data";
        Volumes = {
          "/data" = {};
        };
      };
    in
    {
      packages.${system} = {
        default = ncpsPkg;

        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "ncps";
          tag = "latest";
          created = "now";
          contents = [
            ncpsPkg
            pkgs.bash
            pkgs.coreutils
            pkgs.cacert
          ];
          config = commonConfig;
        };

        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "ncps-debug";
          tag = "latest";
          created = "now";
          contents = [
            ncpsPkg
            # Debug tools
            pkgs.bashInteractive
            pkgs.zsh
            pkgs.coreutils
            pkgs.curl
            pkgs.wget
            pkgs.iproute2
            pkgs.dnsutils
            pkgs.netcat-gnu
            pkgs.tcpdump
            pkgs.socat
            pkgs.mtr
            pkgs.iputils
            pkgs.procps
            pkgs.strace
            pkgs.lsof
            pkgs.htop
            pkgs.psmisc
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
