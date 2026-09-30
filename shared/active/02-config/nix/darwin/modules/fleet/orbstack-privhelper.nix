# OrbStack privileged helper sync (imported by the fleet module)
#
# OrbStack's admin setup (orbctl config setup.use_admin=true) uses a
# privileged helper at /Library/PrivilegedHelperTools/dev.orbstack.OrbStack.
# privhelper for bridged networking, the /var/run/docker.sock symlink, and
# LAN port exposure. OrbStack installs/updates it via SMJobBless, which pops
# a macOS admin-password dialog every time the bundled helper version
# changes (app updates, reinstalls) — even when sudo is NOPASSWD.
#
# This module keeps the helper in sync declaratively, as root, so OrbStack
# always finds a current helper and never needs to prompt:
#
#   1. The helper daemon is declared via launchd.daemons, replacing the
#      SMJobBless-managed plist.
#   2. A one-shot launchd daemon (orbstack-privhelper-sync) runs at load and
#      whenever an OrbStack.app bundle changes (Sparkle auto-update, nix
#      rebuild, cask upgrade), copying the bundled helper into place.
#   3. An activation script runs the same sync at every darwin-rebuild
#      switch for immediacy.
#
# Candidate app bundles, in preference order: the currently-running app's
# bundle, /Applications/OrbStack.app (Homebrew cask / manual install), then
# the nix-managed copy under "/Applications/Nix Apps".
{ pkgs, lib, config, ... }:
let
  cfg = config.infra.fleet;

  syncScript = pkgs.writeShellScript "orbstack-privhelper-sync" ''
    set -euo pipefail

    HELPER="dev.orbstack.OrbStack.privhelper"
    DEST="/Library/PrivilegedHelperTools/$HELPER"

    apps=()
    # Prefer the bundle of the currently-running OrbStack, if any.
    pid=$(/usr/bin/pgrep -f 'OrbStack\.app/Contents/MacOS/OrbStack' | /usr/bin/head -n1 || true)
    if [ -n "$pid" ]; then
      comm=$(/bin/ps -o comm= -p "$pid" 2>/dev/null || true)
      [ -n "$comm" ] && apps+=("''${comm%/Contents/MacOS/OrbStack}")
    fi
    apps+=("/Applications/OrbStack.app" "/Applications/Nix Apps/OrbStack.app")

    for app in "''${apps[@]}"; do
      src="$app/Contents/Library/LaunchServices/$HELPER"
      [ -f "$src" ] || continue
      if ! /usr/bin/cmp -s "$src" "$DEST" 2>/dev/null; then
        /usr/bin/ditto "$src" "$DEST"
        /usr/sbin/chown root:wheel "$DEST"
        /bin/chmod 0755 "$DEST"
        /bin/launchctl kickstart -k "system/$HELPER" 2>/dev/null || true
        echo "orbstack-privhelper-sync: updated $DEST from $app"
      fi
      exit 0
    done
    echo "orbstack-privhelper-sync: no OrbStack.app found; nothing to do"
  '';
in
{
  config = lib.mkIf (cfg.containerRuntime == "orbstack") {
    # The privileged helper daemon itself — identical to the plist SMJobBless
    # installs, but declared so it survives app updates and rebuilds.
    launchd.daemons."dev.orbstack.OrbStack.privhelper" = {
      serviceConfig = {
        Label = "dev.orbstack.OrbStack.privhelper";
        ProgramArguments = [
          "/Library/PrivilegedHelperTools/dev.orbstack.OrbStack.privhelper"
        ];
        MachServices."dev.orbstack.OrbStack.privhelper" = true;
      };
    };

    # One-shot sync daemon: fires at boot and whenever an OrbStack.app
    # bundle is created or replaced (Sparkle update, nix rebuild, cask
    # upgrade). Copies the newest bundled helper into place as root.
    launchd.daemons."dev.infrahub.orbstack-privhelper-sync" = {
      serviceConfig = {
        Label = "dev.infrahub.orbstack-privhelper-sync";
        ProgramArguments = [ "${syncScript}" ];
        RunAtLoad = true;
        WatchPaths = [
          "/Applications/OrbStack.app"
          "/Applications/Nix Apps/OrbStack.app"
        ];
        StandardOutPath = "/var/log/orbstack-privhelper-sync.log";
        StandardErrorPath = "/var/log/orbstack-privhelper-sync.log";
      };
    };

    # Run the sync during activation so a rebuild fixes a stale helper
    # immediately rather than waiting for the next app change.
    system.activationScripts.orbstack-privhelper.text = ''
      ${syncScript} || true
    '';
  };
}
