{
  description = "BentoPDF Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the application derivation (Static Site)
      app = pkgs.stdenv.mkDerivation {
        pname = "bentopdf";
        version = "1.11.2";

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let baseName = baseNameOf (toString path); in
            ! (
              baseName == "flake.nix" ||
              baseName == "flake.lock" ||
              baseName == "docker-compose.yml" ||
              baseName == "Makefile" ||
              baseName == ".git" ||
              baseName == ".gitignore" ||
              baseName == "dist" ||
              baseName == "result" ||
              baseName == "README.md" ||
              baseName == "IMPLEMENTATION_PLAN.md" ||
              baseName == "CHANGELOG.md" ||
              baseName == ".copier-answers.yml" ||
              baseName == ".dockerignore"
            );
        };

        installPhase = ''
          mkdir -p $out/share/nginx/html
          cp -r * $out/share/nginx/html/
        '';
      };

      # Nginx configuration
      nginxConf = pkgs.writeText "nginx.conf" ''
        user nobody nogroup;
        worker_processes auto;
        daemon off;
        events {
          worker_connections 1024;
        }
        http {
          include ${pkgs.nginx}/conf/mime.types;
          default_type application/octet-stream;
          sendfile on;
          keepalive_timeout 65;
          server {
            listen 8080;
            server_name localhost;
            root ${app}/share/nginx/html;
            index index.html;
            location / {
              try_files $uri $uri/ /index.html;
            }
          }
        }
      '';

      # Common configuration for both images
      commonConfig = {
        Cmd = [ "${pkgs.nginx}/bin/nginx" "-c" "${nginxConf}" ];
        ExposedPorts = {
          "8080/tcp" = {};
        };
        Env = [
          "SERVICE_NAME=bentopdf"
          "NODE_ENV=production"
          "PATH=/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin"
        ];
      };

    in
    {
      packages.${system} = {
        default = app;

        # Production Image: Minimal + Healthcheck tools
        docker-prod = pkgs.dockerTools.buildLayeredImage {
          name = "bentopdf";
          tag = "latest";
          contents = [
            pkgs.nginx
            pkgs.fakeNss
            pkgs.bashInteractive
            pkgs.curl
            pkgs.coreutils
          ];
          extraCommands = ''
            mkdir -p tmp/nginx_client_body
            mkdir -p var/log/nginx
            mkdir -p var/run
            chown -R nobody:nogroup tmp var
          '';
          config = commonConfig;
        };

        # Debug Image: App + Interactive Tools
        docker-debug = pkgs.dockerTools.buildLayeredImage {
          name = "bentopdf-debug";
          tag = "latest";
          contents = [
            pkgs.nginx
            pkgs.fakeNss
            pkgs.zsh
            pkgs.bashInteractive
            pkgs.curl
            pkgs.coreutils
            pkgs.procps
            pkgs.iproute2
            pkgs.netcat-gnu
            pkgs.vim
          ];
          extraCommands = ''
            mkdir -p tmp/nginx_client_body
            mkdir -p var/log/nginx
            mkdir -p var/run
            chown -R nobody:nogroup tmp var
          '';
          config = commonConfig // {
            Env = commonConfig.Env ++ [
              "PATH=/bin:${pkgs.zsh}/bin:${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:${pkgs.procps}/bin"
            ];
          };
        };
      };
    };
}
