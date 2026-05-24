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
      pkgs = import nixpkgs {
        inherit system;
        # Add binary cache for faster downloads
        config = {
          allowUnfree = false;
          substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            "https://cache.garnix.io"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPSQZNGZfdL7Q="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CXHQrkxhLww6X236k="
            "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr3g="
          ];
        };
      };
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
