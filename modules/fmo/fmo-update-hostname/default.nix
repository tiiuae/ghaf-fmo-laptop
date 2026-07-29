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

    # NOTE: there used to be a `givc.sysvm.services` registration here. It never
    # took effect on any target and upstream has since moved that option under
    # `capabilities`, so it also stopped evaluating. The only place this module
    # is enabled is the docker app-VM, which runs givc's appvm agent - that
    # agent has no `capabilities.services`, only `capabilities.applications`.
    # It also named a unit ("fmo-update-hostname.service") that this module does
    # not define; the real units are fmo-update-avahi-hostname and
    # fmo-update-kernel-hostname. Making these givc-manageable needs upstream
    # support, so the dead registration is removed rather than renamed.

    systemd = {
      # Note: path change only works for local updates.
      paths.fmo-update-avahi-hostname = {
        description = "Monitor hostname file for changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathModified = [ cfg.hostnamePath ];
      };
      services.fmo-update-avahi-hostname =
        let
          setHostnameScript = pkgs.writeShellApplication {
            name = "set-avahi-hostname";
            runtimeInputs = [
              pkgs.avahi
              pkgs.gawk
            ];
            text = ''
              HOSTNAME=$(gawk '{print $1}' ${cfg.hostnamePath})
              if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                avahi-set-host-name "$HOSTNAME" || exit 1
                echo "Avahi hostname set to '$HOSTNAME'"
              else
                echo "Hostname '$HOSTNAME' is empty or wrong format, skipping..." >&2
                exit 0
              fi
            '';
          };
        in
        {
          description = "Update avahi hostname";
          enable = true;
          wantedBy = [ "avahi-daemon.service" ];
          after = [ "avahi-daemon.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${setHostnameScript}/bin/set-avahi-hostname";
          };
        };

      # Registation agent reads os.Hostname(), so we update the kernel hostname.
      # This is also done during boots following the onboarding.
      # TODO Remove this filth
      paths.fmo-update-kernel-hostname = {
        description = "Monitor hostname file for changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathModified = [ cfg.hostnamePath ];
      };
      services.fmo-update-kernel-hostname =
        let
          setHostnameScript = pkgs.writeShellApplication {
            name = "set-kernel-hostname";
            runtimeInputs = [
              pkgs.gawk
            ];
            text = ''
              HOSTNAME=$(gawk '{print $1}' ${cfg.hostnamePath})
              if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                echo "$HOSTNAME" > /proc/sys/kernel/hostname || exit 1
                echo "Kernel hostname set to '$HOSTNAME'"
              else
                echo "Hostname '$HOSTNAME' is empty or wrong format, skipping..." >&2
                exit 0
              fi
            '';
          };
        in
        {
          description = "Update kernel hostname";
          enable = true;
          wantedBy = [ "network-online.target" ];
          after = [ "network-online.target" ];
          requires = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${setHostnameScript}/bin/set-kernel-hostname";
          };
        };
    };
  };
}
