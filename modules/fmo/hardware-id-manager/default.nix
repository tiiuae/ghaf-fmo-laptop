# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.fmo-hardware-id-manager;
in
{
  options.services.fmo-hardware-id-manager = {
    enable = lib.mkEnableOption "Write hardware ID";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fmo-hardware-id-manager =
      let
        writeHardwareId = pkgs.writeShellApplication {
          name = "write-hardware-id";
          runtimeInputs = [
            pkgs.coreutils
          ];
          text = ''
            mkdir -p /persist/common
            tr -d '\n' < /sys/class/dmi/id/product_uuid > /persist/common/hardware-id.txt
          '';
        };
      in
      {
        description = "Make hardware-based device ID available in docker-vm for FMO use";
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = [
          "/sys/class/dmi/id/product_uuid"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${writeHardwareId}/bin/write-hardware-id";
          RemainAfterExit = true;
        };
      };
  };
}
