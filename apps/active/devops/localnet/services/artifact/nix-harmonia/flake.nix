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
      pkgs = nixpkgs.legacyPackages.${system};
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
