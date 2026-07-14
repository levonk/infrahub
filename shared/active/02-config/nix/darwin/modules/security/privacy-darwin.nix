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
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  system.defaults = lib.mkIf isDarwin {
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

      # Safari and Spotlight suggestions / tracking
      "com.apple.Safari" = {
        SendDoNotTrackHTTPHeader = true;
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
      };

      "com.apple.Spotlight" = {
        SuggestionsEnabled = false;
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
