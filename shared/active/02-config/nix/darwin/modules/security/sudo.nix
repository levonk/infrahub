# Security Tier: Sudo configuration
#
# Grants passwordless sudo to the daily-use users (micro, cuser) so that
# user-level LaunchAgents can read the macOS TCC database via `sudo sqlite3`
# to check Accessibility permissions (e.g., the Deskflow accessibility
# checker LaunchAgent). Without this, LaunchAgents running as the GUI user
# cannot use sudo without a TTY for password entry.
#
# auser already has passwordless sudo via the admin group on macOS.
# This extends the same convenience to the daily-use user(s).
#
# SECURITY NOTE: Passwordless sudo is a broad grant. If a narrower rule
# is needed (e.g., only allow `sudo sqlite3 /Library/Application\ Support/...`),
# replace the NOPASSWD: ALL with a command-specific rule. The current
# approach matches the auser/admin group behavior and is consistent with
# how the fleet already operates.
{ ... }:
{
  security.sudo.extraConfig = ''
    # Daily-use users — passwordless sudo for TCC checks and fleet management
    micro ALL=(ALL) NOPASSWD: ALL
    cuser ALL=(ALL) NOPASSWD: ALL
  '';
}
