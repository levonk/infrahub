{
  description = "Nix Snapshotter for K8s Nodes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-snapshotter.url = "github:pdtpartners/nix-snapshotter";
    nix-snapshotter.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-snapshotter }:
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

      # The real package
      snapshotter = nix-snapshotter.packages.${system}.nix-snapshotter;

      # Custom nix.conf with the requested priority strategy
      nixConf = pkgs.writeText "nix.conf" ''
        experimental-features = nix-command flakes

        # Tiered Caching Strategy
        # 1. Harmonia (Regional Smart Store) - Fastest, Deduplicated
        extra-substituters = http://regional-server:5000?priority=30

        # 2. NCPS (Regional Proxy) - Fast, Cached
        extra-substituters = http://regional-server:5001?priority=40

        # 3. Cloud Fallbacks - Reliable but Slower
        extra-substituters = https://cache.nixos.org?priority=80
        # Add your authenticated caches here if needed

        extra-trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      '';

      commonConfig = {
        Entrypoint = [ "${snapshotter}/bin/nix-snapshotter" ];
        Cmd = [ "--log-level=debug" ]; # Default args
        ExposedPorts = {
          "8989/tcp" = {};
        };
        Env = [
          "SERVICE_NAME=nix-snapshotter"
          "SERVICE_PORT=8989"
          "NODE_ENV=production"
          "NIX_CONF_DIR=/etc/nix" # Point to our custom config
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        WorkingDir = "/var/lib/nix-snapshotter";
        Volumes = {
          "/var/lib/nix-snapshotter" = {};
          "/nix/store" = {}; # Needs access to store
        };
      };

    in
    {
      packages.${system} = {
        default = snapshotter;

        # Production Image
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "nix-snapshotter";
          tag = "latest";
          created = "now";
          contents = [
            snapshotter
            pkgs.nix
            pkgs.bash
            pkgs.coreutils
            pkgs.cacert
            pkgs.iana-etc
          ];
          extraCommands = ''
            mkdir -p etc/nix
            cp ${nixConf} etc/nix/nix.conf
            mkdir -p var/lib/nix-snapshotter
          '';
          config = commonConfig;
        };

        # Debug Image
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "nix-snapshotter-debug";
          tag = "latest";
          created = "now";
          contents = [
            snapshotter
            pkgs.nix
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
            pkgs.binutils
            pkgs.tee
            pkgs.gnutar
            pkgs.gzip
            pkgs.unzip
            pkgs.iana-etc
            pkgs.cacert
          ];
          extraCommands = ''
            mkdir -p etc/nix
            cp ${nixConf} etc/nix/nix.conf
            mkdir -p var/lib/nix-snapshotter
          '';
          config = commonConfig // {
            Env = commonConfig.Env ++ [
              "PATH=/bin:${pkgs.zsh}/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.procps}/bin:${pkgs.iproute2}/bin:${pkgs.jq}/bin:${pkgs.vim}/bin"
            ];
          };
        };
      };
    };
}
