{
  description = "ncro - Nix Cache Route Optimizer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ncro.url = "github:manic-systems/ncro";
    ncro.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ncro }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      pkgsFor = system: import nixpkgs {
        inherit system;
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
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          ncroPkg = ncro.packages.${system}.default;

          commonConfig = {
            Entrypoint = [ "${ncroPkg}/bin/ncro" ];
            ExposedPorts = {
              "8081/tcp" = {};
            };
            WorkingDir = "/data";
            Volumes = {
              "/data" = {};
              "/config" = {};
            };
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "NCRO_DB_PATH=/data/routes.db"
            ];
          };
        in
        {
          default = ncroPkg;

          docker-prod = pkgs.dockerTools.buildLayeredImage {
            name = "localnet-nix-ncro";
            tag = "latest";
            created = "now";
            contents = [
              ncroPkg
              pkgs.bash
              pkgs.coreutils
              pkgs.cacert
              pkgs.iana-etc
            ];
            config = commonConfig;
          };

          docker-debug = pkgs.dockerTools.buildLayeredImage {
            name = "localnet-nix-ncro-debug";
            tag = "latest";
            created = "now";
            contents = [
              ncroPkg
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.zsh
              pkgs.curl
              pkgs.wget
              pkgs.iproute2
              pkgs.dnsutils
              pkgs.netcat-gnu
              pkgs.socat
              pkgs.procps
              pkgs.lsof
              pkgs.htop
              pkgs.vim
              pkgs.jq
              pkgs.ripgrep
              pkgs.findutils
              pkgs.tree
              pkgs.gnused
              pkgs.gnugrep
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
        });
    };
}
