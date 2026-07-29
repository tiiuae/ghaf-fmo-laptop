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
    enable = mkEnableOption "propagation of the shared hostname file to this VM's kernel hostname";

    avahi.enable = mkEnableOption ''
      publishing the shared hostname over mDNS from this VM.

      Enable this only where avahi actually publishes, i.e. a VM with
      services.avahi.publish.enable = true. Renaming a non-publishing daemon
      changes nothing that any other host can observe
    '';

    hostnamePath = mkOption {
      description = "Path to the hostname file";
      type = types.path;
      default = "/var/common/hostname";
    };
  };

  # NOTE: there used to be a `givc.sysvm.services` registration in this module.
  # It never took effect on any target and upstream has since moved that option
  # under `capabilities`, so it also stopped evaluating. It named a unit
  # ("fmo-update-hostname.service") that this module does not define; the real
  # units are fmo-update-avahi-hostname and fmo-update-kernel-hostname. Making
  # these givc-manageable needs upstream support, so it was removed, not renamed.
  config = lib.mkMerge [
    (mkIf cfg.avahi.enable {

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
      };
    })

    (mkIf cfg.enable {
      systemd = {
        # This is also done during boots following the onboarding.
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
    })
  ];
}
