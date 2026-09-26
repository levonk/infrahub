# Scheduled disk janitor (launchd user agent)
#
# Runs a daily cleanup as the logged-in user (NOT a root daemon — every
# target is user-owned: ~/Library, the OrbStack socket, the nix user
# profile). Motivated by the 2026 disk-full incident on lzkmbp2016 where
# ~273G of leaked cmux helper bundles accumulated under
# ~/Library/Application Support/cmux/cmux-cua/helper/.
#
# Always runs (cheap):
#   - cmux leak sweep: chmod u+w read-only helper dirs, then delete
#     `.cmux Computer Use.*.app` bundles older than 24h (-mtime +1, so
#     in-flight helpers are not disturbed — ~700 are created per day).
#   - `pnpm store prune` when pnpm is on PATH.
#
# Runs only when free space on / drops below freeSpaceThresholdGB:
#   - `docker system prune -f` (NEVER --volumes)
#   - `docker image prune -a -f --filter until=<dockerUnusedAgeHours>h`
#   - `docker builder prune -f --filter until=<dockerUnusedAgeHours>h`
#   - `nix-collect-garbage --delete-older-than <nixGcOlderThanDays>d`
{ config, pkgs, lib, ... }:
let
  cfg = config.services.disk-janitor;

  # User agents run as the GUI user; derive HOME from system.primaryUser
  # (set in each host config) so the script and log path are correct.
  primaryUser = config.system.primaryUser or null;
  homeDir = if primaryUser == null then "" else "/Users/${primaryUser}";

  janitorScript = pkgs.writeShellScript "disk-janitor" ''
    set -u

    # launchd user agents run with a minimal environment — rebuild PATH
    # explicitly. Verified locations on the fleet (x86_64 Macs):
    #   docker/orbctl: ~/.orbstack/bin (symlinks into OrbStack.app) and
    #     /run/current-system/sw/bin (nix-darwin system profile)
    #   pnpm:          ~/.nix-profile/bin
    #   nix-collect-garbage: /nix/var/nix/profiles/default/bin
    export HOME="''${HOME:-${homeDir}}"
    export PATH="$HOME/.orbstack/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    # OrbStack's docker socket (user-owned, not /var/run/docker.sock).
    export DOCKER_HOST="unix://$HOME/.orbstack/run/docker.sock"

    log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"; }

    log "== disk-janitor run start =="
    log "before: $(df -h / | tail -1)"

    # --- Always: cmux helper-bundle leak sweep -------------------------
    # Leaked bundles are created dr-xr-xr-x, so chmod u+w on directories
    # first or rm -rf cannot remove their contents. -mtime +1 skips
    # bundles younger than 24h (cmux creates ~700/day while running).
    cmux_dir="$HOME/Library/Application Support/cmux/cmux-cua/helper"
    if [ -d "$cmux_dir" ]; then
      before_kb=$(du -sk "$cmux_dir" 2>/dev/null | awk '{print $1}')
      before_kb=''${before_kb:-0}
      find "$cmux_dir" -type d -exec chmod u+w {} + 2>/dev/null || true
      find "$cmux_dir" -name '.cmux Computer Use.*.app' -type d -mtime +1 -prune -exec rm -rf {} + 2>/dev/null || true
      after_kb=$(du -sk "$cmux_dir" 2>/dev/null | awk '{print $1}')
      after_kb=''${after_kb:-0}
      log "cmux sweep: reclaimed $(( (before_kb - after_kb) / 1024 )) MiB"
    else
      log "cmux sweep: $cmux_dir absent, skipped"
    fi

    # --- Always: pnpm store prune (cheap) ------------------------------
    if command -v pnpm >/dev/null 2>&1; then
      pnpm store prune || true
    else
      log "pnpm not on PATH, skipped"
    fi

    # --- Conditional: heavy prunes when free space is low --------------
    # df -k => 1K blocks; $4 = available. Convert to GiB.
    avail_gb=$(df -k / | awk 'NR==2 {print int($4/1048576)}')
    if [ "$avail_gb" -lt ${toString cfg.freeSpaceThresholdGB} ]; then
      log "free space ''${avail_gb} GiB < ${toString cfg.freeSpaceThresholdGB} GiB — running heavy prunes"

      if command -v docker >/dev/null 2>&1; then
        # NEVER pass --volumes: docker volumes hold persistent data.
        docker system prune -f || true
        docker image prune -a -f --filter "until=${toString cfg.dockerUnusedAgeHours}h" || true
        docker builder prune -f --filter "until=${toString cfg.dockerUnusedAgeHours}h" || true
      else
        log "docker not on PATH, skipped"
      fi

      if command -v nix-collect-garbage >/dev/null 2>&1; then
        nix-collect-garbage --delete-older-than "${toString cfg.nixGcOlderThanDays}d" || true
      else
        log "nix-collect-garbage not on PATH, skipped"
      fi
    else
      log "free space ''${avail_gb} GiB >= ${toString cfg.freeSpaceThresholdGB} GiB — heavy prunes skipped"
    fi

    log "after:  $(df -h / | tail -1)"
    log "== disk-janitor run end =="
  '';
in
{
  options.services.disk-janitor = {
    enable = lib.mkEnableOption "Scheduled disk janitor (cmux leak sweep, pnpm prune, low-space docker/nix GC)";

    freeSpaceThresholdGB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = ''
        Run the heavy prunes (docker system/image/builder prune,
        nix-collect-garbage) only when available space on / falls below
        this many GiB. Cheap sweeps always run.
      '';
    };

    dockerUnusedAgeHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 168;
      description = ''
        `until=` filter (in hours) for `docker image prune -a` and
        `docker builder prune` — only remove resources unused for longer
        than this. Default 168h = 7 days.
      '';
    };

    nixGcOlderThanDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = ''
        Age in days passed to `nix-collect-garbage --delete-older-than`.
        Runs as the user agent, so it collects the user profile only.
      '';
    };

    schedule = {
      hour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        default = 3;
        description = "Hour (0-23) of the daily run (StartCalendarInterval)";
      };

      minute = lib.mkOption {
        type = lib.types.ints.between 0 59;
        default = 0;
        description = "Minute (0-59) of the daily run (StartCalendarInterval)";
      };
    };

    logPath = lib.mkOption {
      type = lib.types.str;
      default =
        if homeDir != ""
        then "${homeDir}/Library/Logs/disk-janitor.log"
        else "/tmp/disk-janitor.log";
      description = ''
        Absolute path for the launchd agent's stdout/stderr log
        (StandardOutPath/StandardErrorPath — must be absolute, ~ is not
        expanded). Defaults to ~/Library/Logs/disk-janitor.log for
        system.primaryUser.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # USER agent (~/Library/LaunchAgents) — every cleanup target is
    # user-owned: ~/Library, the OrbStack socket, the nix user profile.
    launchd.user.agents.disk-janitor = {
      script = ''
        exec ${janitorScript}
      '';

      serviceConfig = {
        Label = "org.nix-darwin.disk-janitor";
        RunAtLoad = false;
        StartCalendarInterval = {
          Hour = cfg.schedule.hour;
          Minute = cfg.schedule.minute;
        };
        StandardOutPath = cfg.logPath;
        StandardErrorPath = cfg.logPath;
      };
    };
  };
}
