# system.defaults — macOS system-level preferences (FR-6)
#
# Source: legacy-nix-config/modules/system/darwin/defaults.nix
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
# ponytail: nix-darwin only supports a small set of named system.defaults options
# (dock, finder, loginwindow, screencapture, screensaver, SoftwareUpdate.AutomaticallyInstallMacOSUpdates, etc).
# Arbitrary `system.defaults."com.apple.X"` keys do NOT work — nix-darwin rejects them
# with "The option system.defaults.com does not exist". Use:
#   - system.defaults.CustomUserPreferences  for user-level defaults (~/Library/Preferences)
#   - system.defaults.CustomSystemPreferences for system-level defaults (/Library/Preferences)
#   - system.activationScripts                for root-only `defaults write` (e.g. SoftwareUpdate extras)
# Upgrade path: if nix-darwin adds named options upstream, move keys back to system.defaults.<name>.
{ pkgs, lib, ... }: {
  system.defaults = {
    # --- Named options supported by nix-darwin ---
    dock.autohide = true;
    dock.mru-spaces = false;
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    finder.NewWindowTarget = "Home";
    finder.NewWindowTargetPath = "file://\${HOME}/";
    # ponytail: FinderSpawnTab is not a named nix-darwin finder option (only ~17 are).
    # It's a user-level com.apple.finder preference → managed by chezmoi osx-settings.py,
    # NOT nix-darwin CustomUserPreferences (three-layer split: user prefs = chezmoi).
    finder.ShowPathbar = true;
    finder.ShowStatusBar = true;
    finder.FXDefaultSearchScope = "sccf";
    finder.FXEnableExtensionChangeWarning = false;
    # finder.WarnOnEmptyTrash = false; # Not supported in standard nix-darwin finder module yet
    finder._FXSortFoldersFirst = false;
    loginwindow.LoginwindowText = "Managed by Nix";
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPassword = true;

    # Software Update — only this one is a native nix-darwin option
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

    # App Store app updates — user-level preference, not a named nix-darwin option.
    # CustomUserPreferences writes to ~/Library/Preferences.
    CustomUserPreferences."com.apple.commerce".AutoUpdate = true;
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
