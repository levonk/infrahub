# Security Tier: Privacy (Darwin) — FR-7
#
# Source: levonk-nix-config/modules/security/privacy-darwin.nix
# No changes from source — byte-identical content.
#
# Darwin-specific privacy and telemetry controls. Reduces analytics and
# advertising without disabling core features. Applied unconditionally on
# Darwin; version-specific adjustments can be added later if Apple changes
# keys.
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  system.defaults = lib.mkIf isDarwin {
    # System diagnostics & Apple advertising
    "com.apple.SubmitDiagInfo" = {
      AutoSubmit = false;
      AllowApplePersonalizedAds = false;
    };

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

    # App-level usage analytics (keep apps functional, just reduce
    # telemetry)
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
}
