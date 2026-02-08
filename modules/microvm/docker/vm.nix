# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fmo.appvms.docker;
in
{
  _file = ./vm.nix;

  options.fmo.appvms.docker = {
    enable = lib.mkEnableOption "FMO Docker App VM";
  };

  config = lib.mkIf (cfg.enable && config.ghaf.profiles.laptop-x86.enable or false) {
    ghaf.virtualization.microvm.appvm.vms.docker = {
      enable = true;

      evaluatedConfig = config.ghaf.profiles.laptop-x86.mkAppVm {
        name = "docker";
        mem = 4096;
        vcpu = 4;
        borderColor = "#000000";

        applications = [
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
          inputs.self.nixosModules.docker-vm-services
          ./config.nix
        ];
      };
    };
  };
}
