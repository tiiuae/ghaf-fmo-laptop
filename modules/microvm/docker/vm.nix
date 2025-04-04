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
        name = "FMO Onboarding Agent";
        description = "FMO Onboarding Agent";
        packages = [
          pkgs.onboarding-agent
          pkgs.fmo-onboarding
          pkgs.papirus-icon-theme
        ];
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/rocs.svg";
        command = "foot /run/wrappers/bin/sudo ${pkgs.fmo-onboarding}/bin/fmo-onboarding";
      }
      {
        name = "FMO Offboarding";
        description = "FMO Offboarding - remove registration data";
        packages = [
          pkgs.fmo-offboarding
          pkgs.papirus-icon-theme
        ];
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/places/user-trash.svg";
        command = "foot /run/wrappers/bin/sudo ${pkgs.fmo-offboarding}/bin/fmo-offboarding";
      }
    ];
    extraModules = [
      (import ./config.nix { inherit pkgs lib config; })
    ];
  };
}
