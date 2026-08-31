# Fleet module (FR-4, FR-5)
#
# Defines:
#   - infra.fleet.containerRuntime option (enum: "orbstack" | "apple-container")
#   - users.users.auser admin account
#   - environment.systemPackages with fleet apps (all from nixpkgs)
#
# No HM (NFR-5). No secrets in flake (NFR-2) — auser password stays
# vault-owned, managed by Ansible bootstrap.
{ pkgs, lib, config, ... }:
let
  cfg = config.infra.fleet;

  # espanso re-signed with a stable code-signing identifier.
  #
  # The nixpkgs espanso binary is ad-hoc signed by the linker with
  # Identifier="espanso" (just the filename, unstable). macOS TCC keys
  # Accessibility permissions on the signing identifier, so every store-path
  # change (version bump, transitive dependency change) silently breaks the
  # grant — the daemon detects missing Accessibility, shows the welcome
  # wizard, and exits with status 0 (nixpkgs #517790).
  #
  # Fix: re-sign with -i com.federicoterzi.espanso (matching the
  # CFBundleIdentifier in Info.plist). TCC then keys on the stable bundle
  # identifier and the permission persists across rebuilds. The user still
  # grants Accessibility once on first launch; subsequent darwin-rebuild
  # switches do not invalidate it.
  #
  # This override is Darwin-only (codesign does not exist on Linux).
  espanso-stable = pkgs.espanso.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      /usr/bin/codesign -f -s - -i com.federicoterzi.espanso \
        "$out/Applications/Espanso.app/Contents/MacOS/espanso"
      /usr/bin/codesign -f -s - -i com.federicoterzi.espanso \
        "$out/bin/espanso"
    '';
  });

  # VS Code Insiders — the pre-release build. Runs alongside stable VS Code
  # with a separate config path. The nixpkgs `vscode` derivation accepts an
  # `isInsiders` argument that switches the source URL and binary name.
  vscode-insiders = pkgs.vscode.override { isInsiders = true; };
in
{
  options.infra.fleet = {
    containerRuntime = lib.mkOption {
      type = lib.types.enum [ "orbstack" "apple-container" ];
      default = "orbstack";
      description = ''
        Container runtime to use on this host.
        - "orbstack": OrbStack (works on x86 + ARM, third-party)
        - "apple-container": Apple Container (macOS 26+ ARM only, native)
      '';
    };
  };

  config = {
    # Allow unfree packages in nixpkgs for fleet apps (Firefox Dev Edition,
    # Raycast, OrbStack, RustDesk, etc.).
    # Nixpkgs 26.11 dropped x86_64-darwin; the x86 host uses 26.05 where
    # it's deprecated but still supported — force it through.
    nixpkgs.config = {
      allowUnfree = true;
      allowDeprecatedx86_64Darwin = lib.mkIf (pkgs.system == "x86_64-darwin") "force";
    };

    # Admin user account — replaces imperative sysadminctl/dscl creation
    # Password stays vault-owned (Ansible bootstrap sets it), not managed here.
    users.users.auser = {
      name = "auser";
      home = "/Users/auser";
      # nix-darwin: add to admin group for sudo access
      # The 'admin' group is the macOS admin group (equivalent to wheel on Linux)
    };

    # Fleet apps — all from nixpkgs (FR-5: prefer Nix packages over casks)
    # orbstack and rustdesk moved from Homebrew casks to Nix packages.
    #
    # Deduplication rule (ADR-202607070001 supplement): any package listed
    # here must NOT also appear in homebrew.brews or homebrew.casks.
    #
    # espanso: text expander. Config is file-based and managed via chezmoi
    # in the dotfiles repo (dot_config/espanso/ + Library/Application Support/espanso/).
    # Uses the espanso-stable override above (re-signed with a stable
    # code-signing identifier) so macOS Accessibility permissions persist
    # across darwin-rebuild switches (nixpkgs #517790 workaround).
    # First-launch only: grant Accessibility once via the welcome wizard or
    # System Settings → Privacy & Security → Accessibility.
    #
    # Browsers: firefox-devedition-bin (Firefox Developer Edition), brave.
    # Communication: discord, zoom-us.
    # Security: bitwarden-desktop (password manager).
    # Editor: vscode-insiders (pre-release VS Code, see override above).
    #
    # CLI tools migrated from imperative `nix profile install`:
    #   cargo, coreutils, delta, difftastic, eza, gh, git-lfs, nodejs, pnpm
    # These were previously installed via `nix profile install nixpkgs#<pkg>`
    # and are now declarative. `nix profile list` should show empty (or only
    # flake-based entries like devbox) after `darwin-rebuild switch`.
    environment.systemPackages = with pkgs;
      [
        # --- Fleet GUI apps ---
        git
        zsh
        tailscale
        netbird
        firefox-devedition
        brave
        raycast
        espanso-stable
        vscode-insiders
        discord
        zoom-us
        bitwarden-desktop
        stirling-pdf-desktop

        # --- CLI tools (migrated from nix profile) ---
        cargo
        coreutils
        delta
        difftastic
        eza
        gh
        git-lfs
        mas
        nodejs
        pnpm

        # --- Secret scanning ---
        gitleaks
        git-secrets

        # --- Git workflow tools ---
        git-imerge
        quilt
        guilt

        # --- Search / file / data tools ---
        ripgrep
        bat
        jq
        yq-go

        # --- Linting / formatting / testing ---
        shellcheck
        shfmt
        bats

        # --- Dev workflow tools ---
        just
        direnv
        jujutsu
        ast-grep
        copier
        jinja2-cli
        pyright

        # --- Security tools ---
        fwknop # SPA (Single Packet Authorization) client for OCI SSH access
        yara-x
        rtk
      ]
      ++ lib.optional (cfg.containerRuntime == "orbstack") orbstack
      ++ lib.optional (cfg.containerRuntime == "apple-container") container
      # treehouse (git worktree pool manager) — provided via a flake overlay
      # in client flakes that declare the treehouse input. Guarded so shared
      # module consumers without the overlay don't fail.
      ++ lib.optional (pkgs ? treehouse) pkgs.treehouse;
  };
}
