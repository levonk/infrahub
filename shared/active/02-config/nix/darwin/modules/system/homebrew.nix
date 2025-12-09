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
      "firefox-developer-edition"
      "google-chrome"      # Google Chrome browser
      "visual-studio-code" # VS Code editor (auto-updating on macOS)
      "visual-studio-code-insiders"
      "iterm2"             # iTerm2 terminal emulator
      "docker"             # Docker Desktop for macOS
      "raycast"
      "alt-tab"
      "hiddenbar"
      "stats"
      "itsycal"
      "figma"
      "spotify"
      "slack"
      "discord"
      "signal"
      "telegram"
      "zoom"
      "vlc"
      "keka"
      "kap"
      "keycastr"
    ];
  };
}
