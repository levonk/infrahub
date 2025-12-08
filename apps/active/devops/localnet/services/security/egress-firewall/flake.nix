{
  description = "Minimal Egress Firewall Sidecar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Wrapper to ensure strict bash usage and location
      entrypointScript = pkgs.runCommand "entrypoint-setup" {} ''
        mkdir -p $out/bin
        cp ${./entrypoint.sh} $out/bin/entrypoint.sh
        chmod +x $out/bin/entrypoint.sh
      '';
    in
    {
      packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
        name = "egress-firewall";
        tag = "latest";

        # created = "now"; # reproducible builds usually prefer strict timestamps, but 'now' is good for dev

        contents = with pkgs; [
          bashInteractive
          iptables
          coreutils
          gnugrep
          gawk
          iproute2
          procps
          entrypointScript
        ];

        config = {
          Entrypoint = [ "/bin/entrypoint.sh" ];
          Env = [
            "PATH=/bin:/usr/bin:/sbin:/usr/sbin"
          ];
          User = "root";
        };
      };
    };
}
