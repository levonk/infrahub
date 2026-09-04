# Security Tier: Sudo configuration
#
# Grants passwordless sudo to the daily-use users (micro, cuser) via
# separate per-user files in /etc/sudoers.d/, matching the bootstrap
# pattern used for auser (/etc/sudoers.d/auser).
#
# auser gets NOPASSWD via the bootstrap shell script (bootstrap-macos-manual.sh)
# because it needs sudo before nix-darwin is available. micro and cuser are
# managed declaratively here because auser can run darwin-rebuild switch to
# apply them.
#
# Each user gets a separate file so individual grants can be audited and
# revoked independently.
#
# SECURITY NOTE: Passwordless sudo is a broad grant. If a narrower rule
# is needed (e.g., only allow `sudo sqlite3 /Library/Application\ Support/...`),
# replace the NOPASSWD: ALL with a command-specific rule.
{ ... }:
{
  # Use environment.etc instead of security.sudo.extraConfig so each user
  # gets a separate file in /etc/sudoers.d/ (extraConfig writes all rules
  # to a single file).
  environment.etc."sudoers.d/micro".text = ''
    micro ALL=(ALL) NOPASSWD: ALL
  '';
  environment.etc."sudoers.d/cuser".text = ''
    cuser ALL=(ALL) NOPASSWD: ALL
  '';
}
