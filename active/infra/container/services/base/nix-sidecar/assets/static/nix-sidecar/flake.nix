{
  description = "A flake for nix-sidecar development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: {
    devShell.x86_64-linux =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
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
      in
      pkgs.mkShell {
        packages = with pkgs; [
          shadow
          gosu
          busybox
          supercronic
          cacert
        ];

        shellHook = ''
          echo "Entering nix-sidecar development environment"

          # Configure trusted users dynamically for Nix builds
          if [ -f /etc/nix/nix.conf ]; then
            # Build trusted-users list - use basic approach without external commands
            TRUSTED_USERS="root"

            # Add common container users that might be used
            for user in cuser devuser debuser nixuser; do
              # Check if user exists by trying to get their ID
              if id "$user" >/dev/null 2>&1; then
                TRUSTED_USERS="$TRUSTED_USERS $user"
              fi
            done

            # Add current USERNAME if it exists and isn't already included
            if [ -n "$USERNAME" ] && id "$USERNAME" >/dev/null 2>&1; then
              # Simple check if USERNAME is already in TRUSTED_USERS
              case " $TRUSTED_USERS " in
                *" $USERNAME "*)
                  # USERNAME already included
                  ;;
                *)
                  TRUSTED_USERS="$TRUSTED_USERS $USERNAME"
                  ;;
              esac
            fi

            # Set NIX_CONFIG environment variable for this nix develop session
            export NIX_CONFIG="trusted-users = $TRUSTED_USERS"
            echo "✅ Configured trusted-users in nix develop: $TRUSTED_USERS"
          else
            echo "❌ nix.conf not found"
          fi
        '';
      };

    # Provide default package for compatibility
    defaultPackage.x86_64-linux =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
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
      in
      pkgs.mkShell {
        packages = with pkgs; [
          shadow
          gosu
          busybox
          supercronic
          cacert
        ];

        shellHook = ''
          echo "Entering nix-sidecar development environment"

          # Configure trusted users dynamically for Nix builds
          if [ -f /etc/nix/nix.conf ]; then
            # Build trusted-users list - use basic approach without external commands
            TRUSTED_USERS="root"

            # Add common container users that might be used
            for user in cuser devuser debuser nixuser; do
              # Check if user exists by trying to get their ID
              if id "$user" >/dev/null 2>&1; then
                TRUSTED_USERS="$TRUSTED_USERS $user"
              fi
            done

            # Add current USERNAME if it exists and isn't already included
            if [ -n "$USERNAME" ] && id "$USERNAME" >/dev/null 2>&1; then
              # Simple check if USERNAME is already in TRUSTED_USERS
              case " $TRUSTED_USERS " in
                *" $USERNAME "*)
                  # USERNAME already included
                  ;;
                *)
                  TRUSTED_USERS="$TRUSTED_USERS $USERNAME"
                  ;;
              esac
            fi

            # Set NIX_CONFIG environment variable for this nix develop session
            export NIX_CONFIG="trusted-users = $TRUSTED_USERS"
            echo "✅ Configured trusted-users in nix develop: $TRUSTED_USERS"
          else
            echo "❌ nix.conf not found"
          fi
        '';
      };

    # Default app for running the shell
    apps.x86_64-linux.default = {
      type = "app";
      program = "${nixpkgs.legacyPackages.x86_64-linux.bash}/bin/bash";
    };
  };
}
