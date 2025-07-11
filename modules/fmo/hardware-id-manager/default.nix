# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  ...
}:

{
  config = {
    systemd.services.fmo-hardware-id-manager = {
      description = "Manage FMO Hardware ID";
      script = ''
        ${pkgs.coreutils}/bin/mkdir -p /persist/common
        ${pkgs.coreutils}/bin/cat /sys/class/dmi/id/product_uuid | ${pkgs.coreutils}/bin/tr -d '\n' > /persist/common/hardware-id.txt
      '';
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "multi-user.target" ];
    };
  };
}
