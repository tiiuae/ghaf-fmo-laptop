# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  config,
  lib,
  pkgs,
  ...
}:
{
  docker = {
    enable = true;
    borderColor = "#000000";
    applications = [
      # TODO this is largely untested
      {
        name = "FMO Registration Agent";
        description = "FMO Registration Agent";
        packages = [
          pkgs.registration-agent
          pkgs.fmo-registration
          pkgs.papirus-icon-theme
        ];
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/rocs.svg";
        command = "foot /run/wrappers/bin/sudo ${pkgs.fmo-registration}/bin/fmo-registration";
      }
    ];
    extraModules = [
      (import ./config.nix { inherit pkgs lib config; })
    ];
  };
}
