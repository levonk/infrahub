# Scheduled nix store GC (launchd system daemon)
#
# Root counterpart to disk-janitor: the user agent can only age out
# user-profile generations, so nix-darwin system generations accumulate
# forever. This daemon runs `nix-collect-garbage --delete-older-than
# <days>d` as root, which also prunes old entries under
# /nix/var/nix/profiles (system generations) — each darwin-system
# generation is multiple GiB of store paths.
#
# `--delete-older-than` keeps a rollback window: only generations/dead
# paths older than nixGcOlderThanDays are removed.
{ config, pkgs, lib, ... }:
let
  cfg = config.services.nix-gc;

  gcScript = pkgs.writeShellScript "nix-gc" ''
    set -u
    export PATH="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"; }

    log "== nix-gc run start =="
    log "before: $(df -h / | tail -1)"
    nix-collect-garbage --delete-older-than "${toString cfg.nixGcOlderThanDays}d" || true
    log "after:  $(df -h / | tail -1)"
    log "== nix-gc run end =="
  '';
in
{
  options.services.nix-gc = {
    enable = lib.mkEnableOption "Scheduled nix store GC (root launchd daemon)";

    nixGcOlderThanDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = ''
        Age in days passed to `nix-collect-garbage --delete-older-than`.
        Runs as root, so it collects system profiles (nix-darwin
        generations) as well as user profiles.
      '';
    };

    schedule = {
      weekday = lib.mkOption {
        type = lib.types.ints.between 0 6;
        default = 0;
        description = "Weekday (0=Sunday) of the weekly run (StartCalendarInterval)";
      };

      hour = lib.mkOption {
        type = lib.types.ints.between 0 23;
        default = 4;
        description = "Hour (0-23) of the weekly run (StartCalendarInterval)";
      };

      minute = lib.mkOption {
        type = lib.types.ints.between 0 59;
        default = 30;
        description = "Minute (0-59) of the weekly run (StartCalendarInterval)";
      };
    };

    logPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/nix-gc.log";
      description = ''
        Absolute path for the launchd daemon's stdout/stderr log
        (StandardOutPath/StandardErrorPath — must be absolute).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # SYSTEM daemon — GC of /nix/var/nix/profiles requires root.
    launchd.daemons.nix-gc = {
      script = ''
        /bin/wait4path /nix/store && exec ${gcScript}
      '';

      serviceConfig = {
        Label = "org.nix-darwin.nix-gc";
        RunAtLoad = false;
        StartCalendarInterval = {
          Weekday = cfg.schedule.weekday;
          Hour = cfg.schedule.hour;
          Minute = cfg.schedule.minute;
        };
        StandardOutPath = cfg.logPath;
        StandardErrorPath = cfg.logPath;
      };
    };
  };
}
