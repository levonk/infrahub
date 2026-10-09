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

  # orbstack 2.1.3 (nixpkgs-26.05-darwin) ships
  # xbin/docker-credential-osxkeychain as a symlink to docker-tools, but
  # docker-tools does not implement that argv0 — it exits with
  # "unsupported argv0". The package globs xbin/* into $out/bin, so the
  # broken shim lands in /run/current-system/sw/bin and shadows OrbStack's
  # own working helper (/usr/local/bin is later in PATH). Since
  # ~/.docker/config.json sets credsStore=osxkeychain, every `docker pull`
  # calls the broken shim and fails.
  #
  # Drop the shim instead of repointing it at nixpkgs' standalone
  # docker-credential-helpers: that binary has a different code-signing
  # identity than the helper that wrote the existing keychain items, so
  # every `get` triggers a GUI SecurityAgent approval prompt — which hangs
  # headless callers (Ansible) indefinitely. With the shim removed, PATH
  # resolution falls through to /usr/local/bin/docker-credential-osxkeychain
  # (OrbStack-installed, already trusted by the stored items' ACLs).
  orbstack-credfix = pkgs.orbstack.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm -f "$out/bin/docker-credential-osxkeychain"
    '';
  });

  # nono (nolabs-ai) — skip cargo tests. Upstream v0.74 has a session-file
  # test that writes to $TMPDIR in a way the nix build sandbox rejects
  # (Errno 22 on write). The other ~1954 tests pass; this is a
  # sandbox-semantics artifact, not a runtime defect.
  nono-nocheck = pkgs.nono.overrideAttrs (old: {
    doCheck = false;
  });
in
{
  imports = [
    # Keeps OrbStack's /Library/PrivilegedHelperTools helper in sync as
    # root so OrbStack never pops an SMJobBless admin-password dialog.
    ./orbstack-privhelper.nix
  ];

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
    # nixpkgs.config (allowUnfree, allowDeprecatedx86_64Darwin) is set in the
    # client flake's mkPkgs function, not here. Setting nixpkgs.config in a
    # module causes nix-darwin to re-import nixpkgs internally (via
    # defaultPkgs), which fails on x86_64-darwin because nix-darwin's
    # nixpkgs.source points to nixpkgs-unstable (26.11) for the non-x86
    # nix-darwin input. The mkPkgs function in the client flake already
    # sets allowUnfree = true and permittedInsecurePackages.

    # Admin user account — replaces imperative sysadminctl/dscl creation
    # Password stays vault-owned (Ansible bootstrap sets it), not managed here.
    users.users.auser = {
      name = "auser";
      home = "/Users/auser";
      # nix-darwin: add to admin group for sudo access
      # The 'admin' group is the macOS admin group (equivalent to wheel on Linux)
    };

    # Fleet apps — all from nixpkgs (FR-5: prefer Nix packages over casks)
    # orbstack moved from a Homebrew cask to a Nix package. rustdesk tried
    # the same move but nixpkgs marks darwin as badPlatforms, so it remains
    # a cask in the homebrew module.
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
    # Remote desktop: rustdesk is a Homebrew cask — nixpkgs marks darwin
    # as badPlatforms (the Flutter/Rust source build doesn't support
    # macOS). Client prefs (ID/relay server endpoints) are set per-client,
    # e.g. levonk's modules/rustdesk-client.nix.
    #
    # Container / agent-sandbox tooling (all CLI):
    #   colima    — container runtimes on macOS via Lima (docker-compat VM)
    #   podman    — podman-remote client; `podman machine` helpers
    #               (gvproxy/vfkit/krunkit) are wrapped into the derivation
    #   openshell — NVIDIA OpenShell sandboxed runtime for AI agents
    #   nono      — kernel-enforced sandbox for agent/MCP workloads
    #               (nixpkgs homepage lists the old always-further org;
    #               upstream is now nolabs-ai/nono — same repo, renamed;
    #               nono-nocheck disables a sandbox-hostile unit test)
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
        brave
        raycast
        espanso-stable
        vscode-insiders
        discord
        zoom-us
        bitwarden-desktop
        stirling-pdf-desktop

        # --- Container / agent-sandbox tooling ---
        colima
        podman
        openshell
        nono-nocheck

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
        # fwknop (SPA client) is Linux-only — meta.platforms excludes Darwin.
        # Guarded so macOS hosts skip it; macOS uses the fwknop client via
        # Homebrew or a separate install path.
        yara-x
        rtk
      ]
      ++ lib.optional (pkgs.stdenv.hostPlatform.isLinux) fwknop
      ++ lib.optional (cfg.containerRuntime == "orbstack") orbstack-credfix
      ++ lib.optional (cfg.containerRuntime == "apple-container") container
      # treehouse (git worktree pool manager) — provided via a flake overlay
      # in client flakes that declare the treehouse input. Guarded so shared
      # module consumers without the overlay don't fail.
      ++ lib.optional (pkgs ? treehouse) pkgs.treehouse;
  };
}
