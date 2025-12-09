{ pkgs, ... }: {
  system.defaults = {
    dock.autohide = true;
    dock.mru-spaces = false;
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    finder.NewWindowTarget = "Home";
    finder.NewWindowTargetPath = "file://\${HOME}/";
    finder.FinderSpawnTab = true;
    finder.ShowPathbar = true;
    finder.ShowStatusBar = true;
    finder.FXDefaultSearchScope = "SCcf";
    finder.FXEnableExtensionChangeWarning = false;
    # finder.WarnOnEmptyTrash = false; # Not supported in standard nix-darwin finder module yet, checking alternatives or custom defaults
    finder._FXSortFoldersFirst = false;
    loginwindow.LoginwindowText = "Managed by Nix";
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPassword = true;

    # Software Update preferences
    # Corresponds to:
    # - Download new updates when available: On
    # - Install macOS updates: On
    # - Install Security Responses and system files: On
    SoftwareUpdate = {
      AutomaticCheckEnabled = true;           # Check for updates automatically
      AutomaticDownload = true;               # Download new updates when available
      AutomaticallyInstallMacOSUpdates = true;# Install macOS updates
      ConfigDataInstall = true;               # Install configuration data
      CriticalUpdateInstall = true;           # Install security responses/system files
    };

    # App Store automatic application updates
    # Corresponds to:
    # - Install application updates from the App Store: On
    com.apple.commerce = {
      AutoUpdate = true;                      # Automatically install app updates
    };
  };
}
