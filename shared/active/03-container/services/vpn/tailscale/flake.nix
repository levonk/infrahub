{
  description = "Tailscale VPN Client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation here
      app = pkgs.stdenv.mkDerivation {
        pname = "vpn-tailscale";
        version = "0.1.0";
        src = ./.;

        # Add your build inputs here
        buildInputs = [ ];

        # Example build phase (adjust as needed)
        buildPhase = ''
          echo "Building vpn-tailscale..."
          # make build
        '';

        installPhase = ''
          mkdir -p $out/bin
          # cp bin/vpn-tailscale $out/bin/

          # Placeholder for demonstration
          echo '#!${pkgs.runtimeShell}' > $out/bin/vpn-tailscale
          echo 'echo "Starting vpn-tailscale on port 8085..."' >> $out/bin/vpn-tailscale
          echo 'while true; do sleep 1; done' >> $out/bin/vpn-tailscale
          chmod +x $out/bin/vpn-tailscale
        '';
      };

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${app}/bin/vpn-tailscale" ];
        ExposedPorts = {
          "8085/tcp" = {};
        };
        Env = [
          "SERVICE_NAME=vpn-tailscale"
          "SERVICE_PORT=8085"
          "NODE_ENV=production"
        ];
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image: Minimal, only app + runtime closure
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "vpn-tailscale";
          tag = "latest";
          contents = [ app ];
          config = commonConfig;
        };

        # Debug Image: App + Interactive Tools
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "vpn-tailscale-debug";
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
