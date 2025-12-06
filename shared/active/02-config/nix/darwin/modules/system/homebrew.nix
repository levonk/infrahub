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
      "1password"
      "firefox"
      "google-chrome"
      "visual-studio-code" # Often better via brew for auto-updates on mac
      "iterm2"
      "docker" # Docker Desktop
    ];
  };
}
