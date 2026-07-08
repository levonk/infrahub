# system.defaults — macOS system-level preferences (FR-6)
#
# Source: levonk-nix-config/modules/system/darwin/defaults.nix
# Changes from source:
#   - SoftwareUpdate.AutomaticallyInstallMacOSUpdates: true -> false (OS auto-install OFF)
#   - SoftwareUpdate.ConfigDataInstall: true -> false (Security Responses OFF)
#   - SoftwareUpdate.CriticalUpdateInstall: true -> false (Security Responses OFF)
#
# Rationale: lzkmbp2016 runs OpenCore; automatic OS updates would break it.
# App Store app updates remain ON (com.apple.commerce.AutoUpdate = true).
#
# Update policy summary:
#   - Download new updates when available: On (AutomaticDownload = true)
#   - Install macOS updates: Off (AutomaticallyInstallMacOSUpdates = false)
#   - Install Security Responses: Off (ConfigDataInstall/CriticalUpdateInstall = false)
#   - Install App Store app updates: On (com.apple.commerce.AutoUpdate = true)
#
# ponytail: nix-darwin only supports system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates.
# The other SoftwareUpdate keys (AutomaticCheckEnabled, AutomaticDownload, ConfigDataInstall,
# CriticalUpdateInstall) are not nix-darwin options — they're set via `defaults write` in
# system.activationScripts (which runs as root, so /Library/Preferences is writable).
# Upgrade path: if nix-darwin adds these options upstream, move them back to system.defaults.
{ pkgs, lib, ... }: {
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
    finder.FXDefaultSearchScope = "sccf";
    finder.FXEnableExtensionChangeWarning = false;
    # finder.WarnOnEmptyTrash = false; # Not supported in standard nix-darwin finder module yet, checking alternatives or custom defaults
    finder._FXSortFoldersFirst = false;
    loginwindow.LoginwindowText = "Managed by Nix";
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPassword = true;

    # Software Update — only this one is a native nix-darwin option
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

    # App Store automatic application updates
    com.apple.commerce = {
      AutoUpdate = true;                      # Automatically install app updates
    };
  };

  # Software Update keys not supported by nix-darwin's system.defaults
  # (AutomaticCheckEnabled, AutomaticDownload, ConfigDataInstall, CriticalUpdateInstall).
  # Set via `defaults write /Library/Preferences/com.apple.SoftwareUpdate` — activationScripts
  # run as root so /Library/Preferences is writable. Idempotent: `defaults write` overwrites.
  system.activationScripts.softwareUpdateExtras.text = ''
    echo "setting SoftwareUpdate extras (ConfigDataInstall, CriticalUpdateInstall, etc.)"
    /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
    /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
    /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool false
    /usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false
  '';
}
