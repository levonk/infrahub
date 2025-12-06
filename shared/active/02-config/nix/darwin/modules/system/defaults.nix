{ pkgs, ... }: {
  system.defaults = {
    dock.autohide = true;
    dock.mru-spaces = false;
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    loginwindow.LoginwindowText = "Managed by Nix";
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPassword = true;
  };
}
