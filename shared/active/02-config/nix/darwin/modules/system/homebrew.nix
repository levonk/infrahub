{ pkgs, ... }: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap"; # Dangerous: removes apps not in this list
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    taps = [
      "homebrew/bundle"
      "homebrew/services"
    ];

    brews = [
      # "mas" # Mac App Store CLI
    ];

    casks = [
      # GUI Apps not available in Nix or better managed by Brew
      "firefox"            # Firefox browser (managed via Homebrew)
      "google-chrome"      # Google Chrome browser
      "visual-studio-code" # VS Code editor (auto-updating on macOS)
      "iterm2"             # iTerm2 terminal emulator
      "docker"             # Docker Desktop for macOS
    ];
  };
}
