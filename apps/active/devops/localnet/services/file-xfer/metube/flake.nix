{
  description = "";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation here
      app = pkgs.stdenv.mkDerivation {
        pname = "";
        version = "0.1.0";
        src = ./.;

        # Add your build inputs here
        buildInputs = [ ];

        # Example build phase (adjust as needed)
        buildPhase = ''
          echo "Building ..."
          # make build
        '';

        installPhase = ''
          mkdir -p $out/bin
          # cp bin/ $out/bin/

          # Placeholder for demonstration
          echo '#!${pkgs.runtimeShell}' > $out/bin/
          echo 'echo "Starting  on port ..."' >> $out/bin/
          echo 'while true; do sleep 1; done' >> $out/bin/
          chmod +x $out/bin/
        '';
      };

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${app}/bin/" ];
        ExposedPorts = {
          "/tcp" = {};
        };
        Env = [
          "SERVICE_NAME="
          "SERVICE_PORT="
          "NODE_ENV=production"
        ];
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image: Minimal, only app + runtime closure
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "";
          tag = "latest";
          contents = [ app ];
          config = commonConfig;
        };

        # Debug Image: App + Interactive Tools
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "-debug";
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
