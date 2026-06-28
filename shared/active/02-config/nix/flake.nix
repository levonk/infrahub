{
  description = "macOS host applications — managed by Nix (multi-user daemon mode)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  # Binary cache — speeds up installs by pulling pre-built packages
  # instead of building from source. Following the pattern from
  # modem-dev/hunk and levonk-nix-config.
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      # Both x86 and ARM Macs supported — auto-detected at install time
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      perSystem = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          # CLI tools — go into the nix profile, available on PATH
          cliApps = with pkgs; [
            git
            zsh
            tailscale
            netbird
          ];
          # GUI apps — .app bundles symlinked to /Applications by symlink-apps
          guiApps = with pkgs; [
            cmux
            firefox-devedition-bin
            raycast
          ];
        in {
          packages = {
            # Meta-package: install all host apps into the nix profile
            #   nix profile install .#host-apps
            host-apps = pkgs.buildEnv {
              name = "macos-host-apps";
              paths = cliApps ++ guiApps;
            };

            # Script: symlink GUI .app bundles from the nix profile to /Applications
            #   nix run .#symlink-apps
            symlink-apps = pkgs.writeShellScriptBin "symlink-apps" ''
              set -euo pipefail
              profile_apps="$HOME/.local/state/nix/profiles/profile/Applications"
              if [ ! -d "$profile_apps" ]; then
                echo "No Applications dir in nix profile — nothing to symlink."
                exit 0
              fi
              echo "Symlinking GUI apps from nix profile to /Applications..."
              for appbundle in "$profile_apps"/*.app; do
                [ -e "$appbundle" ] || continue
                appname=$(basename "$appbundle")
                echo "  $appname"
                ln -sfn "$appbundle" "/Applications/$appname"
              done
              echo "Done."
            '';

            default = pkgs.buildEnv {
              name = "macos-host-apps";
              paths = cliApps ++ guiApps;
            };
          };

          # Apps (nix run .#symlink-apps)
          apps = {
            symlink-apps = {
              type = "app";
              program = "${self.packages.${system}.symlink-apps}/bin/symlink-apps";
              meta.description = "Symlink GUI .app bundles from nix profile to /Applications";
            };
          };
        });
    in {
      packages = lib.mapAttrs (_: value: value.packages) perSystem;
      apps = lib.mapAttrs (_: value: value.apps) perSystem;
    };
}
