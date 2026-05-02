{
  description = "Netbird VPN Client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation here
      # This is a placeholder. In a real scenario, you'd fetch the Netbird binary or build from source.
      app = pkgs.stdenv.mkDerivation {
        pname = "vpn-netbird";
        version = "0.1.0";
        src = ./.;

        # Add your build inputs here
        buildInputs = [ ];

        # Example build phase (adjust as needed)
        buildPhase = ''
          echo "Building vpn-netbird..."
          # make build
        '';

        installPhase = ''
          mkdir -p $out/bin
          # cp bin/vpn-netbird $out/bin/

          # Placeholder for demonstration
          echo '#!${pkgs.runtimeShell}' > $out/bin/vpn-netbird
          echo 'echo "Starting vpn-netbird on port 8084..."' >> $out/bin/vpn-netbird
          echo 'while true; do sleep 1; done' >> $out/bin/vpn-netbird
          chmod +x $out/bin/vpn-netbird
        '';
      };

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${app}/bin/vpn-netbird" ];
        ExposedPorts = {
          "8084/tcp" = {};
        };
        Env = [
          "SERVICE_NAME=vpn-netbird"
          "SERVICE_PORT=8084"
          "NODE_ENV=production"
        ];
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image: Minimal, only app + runtime closure
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "vpn-netbird";
          tag = "latest";
          contents = [ app ];
          config = commonConfig;
        };

        # Debug Image: App + Interactive Tools
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "vpn-netbird-debug";
          tag = "latest";

          # The "Twist": Add debugging tools
          contents = [
            app
            # Shells
            pkgs.zsh
            pkgs.bashInteractive

            # Network
            pkgs.curl
            pkgs.wget
            pkgs.iproute2    # ip, ss
            pkgs.dnsutils    # dig, nslookup
            pkgs.netcat-gnu  # nc
            pkgs.tcpdump
            pkgs.socat
            pkgs.mtr
            pkgs.iputils     # ping

            # System & Process
            pkgs.coreutils
            pkgs.procps      # ps, top, free
            pkgs.strace
            pkgs.lsof
            pkgs.htop
            pkgs.psmisc      # killall, fuser

            # File & Text
            pkgs.vim
            pkgs.jq          # JSON processing
            pkgs.ripgrep     # rg
            pkgs.findutils   # find, xargs
            pkgs.file
            pkgs.tree
            pkgs.gnused
            pkgs.gnugrep
            pkgs.gawk
            pkgs.less
            pkgs.which
            pkgs.binutils    # strings, etc.
            pkgs.tee         # (part of coreutils usually, but ensuring)

            # Archives
            pkgs.gnutar
            pkgs.gzip
            pkgs.unzip

            # Misc
            pkgs.iana-etc    # /etc/services
            pkgs.cacert      # SSL certs
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
