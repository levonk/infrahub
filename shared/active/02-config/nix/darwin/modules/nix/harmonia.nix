# Local Harmonia service for nix-darwin (ADR-20260708001)
#
# Runs Harmonia as a native launchd service on macOS, serving the local
# /nix/store over HTTP on 127.0.0.1. This is the "priority 10" substituter
# in the ADR's cache chain: local store hits are instant (sub-millisecond).
#
# Unlike the containerized Harmonia on dtop202311/oci-cloud-server, this
# runs natively (no OrbStack/Docker) and reads /nix/store directly.
#
# The signing key is stored in the vault and deployed via Ansible to
# /etc/nix/harmonia.secret (readable only by root). The public key is
# distributed to clients via the cache-lan.nix module.
#
# See: shared/active/08-docs/adr/adr-20260708001-nix-cache-chain-regional-parallel-racing.md
{ config, pkgs, lib, ... }:
let
  cfg = config.services.harmonia-darwin;
  format = pkgs.formats.toml { };
  configFile = format.generate "harmonia.toml" cfg.settings;
in
{
  options.services.harmonia-darwin = {
    enable = lib.mkEnableOption "Local Harmonia binary cache (serves /nix/store on 127.0.0.1)";

    package = lib.mkPackageOption pkgs "harmonia" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4523;
      description = "Port to listen on (matches the containerized Harmonia port on dtop202311)";
    };

    workers = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Number of worker threads";
    };

    signKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nix/harmonia.secret";
      description = "Path to the Harmonia signing key (deployed by Ansible from vault)";
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      description = "Extra Harmonia settings (merged with defaults)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.harmonia-darwin.settings = {
      bind = "127.0.0.1:${toString cfg.port}";
      workers = cfg.workers;
      sign_key_paths = [ cfg.signKeyPath ];
    };

    # Launchd service
    launchd.daemons.harmonia = {
      script = ''
        export CONFIG_FILE=${configFile}
        exec ${cfg.package}/bin/harmonia-cache
      '';

      serviceConfig = {
        Label = "org.nix-community.harmonia";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/harmonia.log";
        StandardErrorPath = "/var/log/harmonia.log";
      };
    };
  };
}
