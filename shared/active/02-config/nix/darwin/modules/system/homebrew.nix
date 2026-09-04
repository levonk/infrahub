# Homebrew module (FR-5)
#
# Single source of truth for Homebrew-managed packages.
# Packages available in nixpkgs are installed via environment.systemPackages
# in the fleet module (FR-5) and are NOT duplicated here.
#
# Deduplication rules (ADR-202607070001 supplement):
#   - If a package is in environment.systemPackages, it must NOT be in
#     homebrew.brews or homebrew.casks.
#   - GUI apps available in nixpkgs (raycast, brave, espanso, cmux, discord,
#     bitwarden-desktop, orbstack, firefox-devedition-bin, vscode-insiders,
#     rustdesk) are in the fleet module, NOT here.
#   - Casks listed here are apps NOT available in nixpkgs or that are better
#     managed as casks (e.g., Docker Desktop requires cask-only install).
#   - firefox (stable) and visual-studio-code (stable) are kept as casks
#     because the nix versions are firefox-devedition-bin and vscode-insiders
#     respectively — these are DIFFERENT products, not duplicates.
#
# onActivation.cleanup = "none" is the safe default:
#   - "none": ensures listed packages are installed; does NOT remove extras.
#   - "uninstall": removes casks/formulae not in the list (keeps app data).
#   - "zap": removes casks/formulae not in the list AND all associated files.
# Switch to "uninstall" or "zap" after verifying the lists are complete.
{ pkgs, lib, config, ... }:
let
  # Third-party taps (non-homebrew/*) that need explicit `brew trust`
  # before `brew bundle` can install their casks/formulae.
  # Homebrew 4.x introduced tap-trust as a security feature; taps declared
  # in nix-darwin config are the trust decision, but Homebrew's interactive
  # trust prompt blocks `brew bundle` until `brew trust` is run per-user.
  thirdPartyTaps = [
    "deskflow/tap"
  ];
in {
  homebrew = {
    enable = true;
    onActivation.cleanup = "none"; # Safe: won't remove existing packages
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    # Only third-party taps — homebrew/bundle and homebrew/services were
    # deprecated by Homebrew (taps are now empty, contents migrated to core).
    taps = thirdPartyTaps;

    # CLI tools managed by Homebrew.
    # Excludes: git, zsh (in environment.systemPackages via nix).
    # Includes: tools not yet migrated to nix or that are better as brew
    # formulae (e.g., python@3.14 for broader compatibility, chezmoi and
    # direnv needed before nix-darwin is available during bootstrap).
    brews = [
      # Build / runtime
      "act"
      "deno"
      "python@3.14"

      # Shell / terminal utilities
      "bat"
      "direnv"
      "fd"
      "fzf"
      "htop"
      "jq"
      "just"
      "mosh"
      "ripgrep"
      "sshpass"
      "tmux"
      "zoxide"

      # Editors / development
      "neovim"
      "tree-sitter"
      "universal-ctags"

      # Network / download
      "wget"
      "yt-dlp"

      # Dotfiles / config management (needed during bootstrap, before nix-darwin)
      "chezmoi"

      # Crypto / TLS
      "openssl@3"
    ];

    # GUI apps managed by Homebrew casks.
    # Excludes apps already in environment.systemPackages via nix:
    #   discord, bitwarden-desktop, orbstack (in fleet module)
    casks = [
      # Browsers (firefox stable — Dev Edition is in nix; this is NOT a duplicate)
      "firefox"
      "google-chrome"
      "microsoft-edge"

      # Development tools (vscode stable — Insiders is in nix; NOT a duplicate)
      "visual-studio-code"
      "windsurf"
      "devin-cli"

      # Terminal / KVM / URL routing
      "iterm2"
      "deskflow"
      "finicky"

      # Containers (Docker Desktop — not available in nixpkgs)
      "docker-desktop"

      # Notes / productivity
      "obsidian"

      # Network tunneling
      "ngrok"
    ];
  };

  # Trust third-party taps before `brew bundle` runs.
  # nix-darwin activation scripts run in alphabetical order by key;
  # "brew-trust-taps" (b) runs before "homebrew" (h).
  # This bridges the gap between declarative tap declaration (homebrew.taps)
  # and Homebrew 4.x's interactive tap-trust requirement.
  system.activationScripts.brew-trust-taps.text = let
    primaryUser = config.system.primaryUser or "root";
    trustCommands = map (tap: "  /usr/bin/sudo -u ${primaryUser} -H brew trust ${tap} 2>/dev/null || true") thirdPartyTaps;
  in ''
    # Trust third-party Homebrew taps before brew bundle runs.
    # Homebrew 4.x requires explicit `brew trust` for non-homebrew/* taps.
    # The taps are declared in homebrew.taps above — this is the trust step.
    ${builtins.concatStringsSep "\n" trustCommands}
  '';
}
