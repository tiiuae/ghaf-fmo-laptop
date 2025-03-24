# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fmo-update-hostname;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.services.fmo-update-hostname = {
    enable = mkEnableOption "";
    hostnamePath = mkOption {
      description = "Path to the hostname file";
      type = types.path;
      default = "/var/common/hostname";
    };
  };

  config = mkIf cfg.enable {

    # Add fmo-update-hostname service to givc
    givc.sysvm.services = [
      "fmo-update-hostname.service"
    ];

    systemd = {
      # Note: path change only works for local updates.
      paths.fmo-update-hostname = {
        description = "Monitor hostname file for changes";
        wantedBy = [ "avahi-daemon.service" ];
        after = [ "avahi-daemon.service" ];
        pathConfig.PathModified = [ cfg.hostnamePath ];
      };
      services.fmo-update-hostname =
        let
          setHostnameScript = pkgs.writeShellApplication {
            name = "set-avahi-hostname";
            runtimeInputs = [
              pkgs.avahi
              pkgs.gawk
            ];
            text = ''avahi-set-host-name "$(gawk '{print $1}' ${cfg.hostnamePath})"'';
          };
        in
        {
          description = "Update avahi hostname";
          enable = true;
          wantedBy = [ "avahi-daemon.service" ];
          after = [ "avahi-daemon.service" ];
          serviceConfig = {
            type = "oneshot";
            ExecStart = "${setHostnameScript}/bin/set-avahi-hostname";
          };
        };
    };
  };
}
