{
  description = "Harmonia - Nix Binary Cache";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    harmonia.url = "github:nix-community/harmonia";
    harmonia.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, harmonia }:
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
      harmoniaPkg = harmonia.packages.${system}.default;

      commonConfig = {
        Entrypoint = [ "${harmoniaPkg}/bin/harmonia" ];
        ExposedPorts = {
          "5000/tcp" = {};
        };
        WorkingDir = "/data";
        Volumes = {
          "/data" = {};
          "/nix/store" = {};
        };
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
      };
    in
    {
      packages.${system} = {
        default = harmoniaPkg;

        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "harmonia";
          tag = "latest";
          created = "now";
          contents = [
            harmoniaPkg
            pkgs.bash
            pkgs.coreutils
            pkgs.nix
            pkgs.iana-etc
            pkgs.cacert
          ];
          config = commonConfig;
        };

        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "harmonia-debug";
          tag = "latest";
          created = "now";
          contents = [
            harmoniaPkg
            pkgs.nix
            pkgs.bashInteractive
            pkgs.coreutils
            # Debug tools
            pkgs.zsh
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
