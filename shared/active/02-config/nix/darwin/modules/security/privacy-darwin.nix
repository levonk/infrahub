# Security Tier: Privacy (Darwin) — FR-7
#
# Source: levonk-nix-config/modules/security/privacy-darwin.nix
# Changes from source:
#   - All `system.defaults."com.apple.X"` moved to CustomUserPreferences /
#     CustomSystemPreferences (the original form never worked — nix-darwin rejects
#     arbitrary system.defaults."com.apple.X" keys with "The option system.defaults.com
#     does not exist". levonk-nix-config was never deployed, so this was never caught.)
#
# Darwin-specific privacy and telemetry controls. Reduces analytics and
# advertising without disabling core features. Applied unconditionally on
# Darwin; version-specific adjustments can be added later if Apple changes
# keys.
#
# ponytail: nix-darwin does NOT support arbitrary system.defaults."com.apple.X" keys.
# Use CustomUserPreferences (~/Library/Preferences) for user-level and
# CustomSystemPreferences (/Library/Preferences) for system-level.
# SubmitDiagInfo is system-level (diagnostics submission affects the whole machine);
# the rest are user-level (per-user app preferences).
# Upgrade path: if nix-darwin adds named options upstream, move keys back to system.defaults.<name>.
{ pkgs, lib, config, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  # Sandboxed apps store prefs inside ~/Library/Containers — writing those
  # domains via `defaults` requires Full Disk Access, which headless SSH
  # sessions lack on macOS 26+. Gate them so headless deploys can disable.
  containerized = config.infra.security.userContainerDefaults;
in
{
  options.infra.security.userContainerDefaults = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Write preference domains for sandboxed apps (Safari, Maps, Health,
      iMessage, Photos). Their ~/Library/Containers plist paths require
      Full Disk Access on macOS 26+, so activation over SSH fails — set to
      false on headless-deployed hosts.
    '';
  };

  config.system.defaults = lib.mkIf isDarwin {
    # System-level privacy: diagnostics submission (affects whole machine)
    CustomSystemPreferences."com.apple.SubmitDiagInfo" = {
      AutoSubmit = false;
      AllowApplePersonalizedAds = false;
    };

    # User-level privacy: per-app preferences
    CustomUserPreferences = {
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };

      "com.apple.iCloud" = {
        EnableAnalytics = false;
      };

      "com.apple.Spotlight" = {
        SuggestionsEnabled = false;
      };
    } // lib.optionalAttrs containerized {
      # Safari and Spotlight suggestions / tracking
      "com.apple.Safari" = {
        SendDoNotTrackHTTPHeader = true;
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
      };

      # App-level usage analytics (keep apps functional, just reduce telemetry)
      "com.apple.Maps" = {
        UserSelectedAnonymousUsageOptIn = false;
      };

      "com.apple.Health" = {
        UserSelectedAnonymousUsageOptIn = false;
      };

      "com.apple.imessage" = {
        UserSelectedAnonymousUsageOptIn = false;
      };

      "com.apple.Photos" = {
        UserSelectedAnonymousUsageOptIn = false;
      };
    };
  };
}
