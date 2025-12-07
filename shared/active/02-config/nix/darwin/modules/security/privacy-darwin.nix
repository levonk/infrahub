# Security Tier: Privacy (Darwin)
#
# Darwin-specific privacy and telemetry controls live here so they can be
# managed independently from general security hardening. This module is
# intentionally a no-op today; it exists as a structured home for future
# macOS `system.defaults` and related settings once reliable keys are
# captured from a real system.
#
# Examples of future responsibilities (documented in
# `internal-docs/security/privacy-hardening.md`):
# - Analytics & Improvements toggles (Share Mac Analytics, Improve Siri &
#   Dictation, Share with app developers, Share iCloud Analytics, etc.).
# - Apple Advertising / Personalized Ads.
# - Additional privacy-relevant defaults or profiles that are specific to
#   macOS and do not apply to other platforms.
#
# Until those keys are known and validated, importing this module has no
# effect on any platform (including Darwin).
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # Baseline macOS privacy defaults: reduce analytics and advertising
  # without disabling core features like Siri or globally killing
  # Location Services. Applied unconditionally on Darwin; version-
  # specific adjustments can be added later if Apple changes keys.

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
