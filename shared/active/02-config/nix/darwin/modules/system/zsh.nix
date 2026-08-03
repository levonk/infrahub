# Zsh system configuration — /etc/zshenv ownership
#
# ADR-202607070001 supplement: nix-darwin owns /etc/zshenv and /etc/zshrc
# (system-wide zsh startup files). The user's real zsh configuration lives
# in chezmoi-managed ~/.config/shells/ (dotfiles repo).
#
# Architecture:
#   /etc/zshenv  (nix-darwin)  → minimal: set PATH for /run/current-system/sw/bin
#   ~/.zshenv    (chezmoi)     → sets ZDOTDIR=~/.config/shells/zsh, sources shared env
#   $ZDOTDIR/.zshrc (chezmoi)  → interactive shell setup, entrypoint.zsh, lazy loading
#
# This split prevents conflicts:
#   - nix-darwin rewrites /etc/zshenv on every darwin-rebuild switch
#   - chezmoi rewrites ~/.zshenv on every chezmoi apply
#   - The two files have different responsibilities and never overwrite each other
#
# programs.zsh.enable installs nix-darwin's zsh and sets it as the default
# shell via /etc/shells. The nix-provided zsh is used instead of the
# Homebrew one (Homebrew zsh is NOT in homebrew.brews — no duplication).
{ pkgs, lib, ... }: {
  # Use nix-darwin's zsh as the system shell
  programs.zsh.enable = true;

  # /etc/zshenv — minimal, system-wide.
  # Only adds the nix-darwin system profile to PATH. All user-level zsh
  # config is in chezmoi-managed ~/.zshenv (sets ZDOTDIR) and
  # ~/.config/shells/ (the actual framework).
  #
  # nix-darwin already writes /etc/zshenv with PATH setup via its
  # environment module. We don't need to override it — just document
  # that this is the intended architecture.
  #
  # If you need to add system-wide zshenv content, use:
  #   environment.etc."zshenv".text = ''
  #     # System-wide zshenv — managed by nix-darwin
  #     # User config is in ~/.zshenv (chezmoi) → ~/.config/shells/
  #   '';
  # But the default nix-darwin /etc/zshenv is already correct.

  # /etc/shells — include nix-darwin's zsh
  # nix-darwin's programs.zsh.enable handles this automatically.

  # Explicitly do NOT set /etc/zshrc — chezmoi's ~/.zshenv sets ZDOTDIR
  # to ~/.config/shells/zsh/, so zsh reads $ZDOTDIR/.zshrc (chezmoi-managed)
  # instead of /etc/zshrc. Setting /etc/zshrc here would be dead weight.
}
