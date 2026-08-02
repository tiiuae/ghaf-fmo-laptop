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
          # NOTE: desktopName must stay byte-identical to the old `name`. The
          # GIVC app id is derived from it as
          #   toLower (replaceStrings [" "] ["-"] desktopName)
          # and the gui-VM launcher invokes that id, so changing it would break
          # the launchers. `exec` keeps the old `command` value verbatim: ghaf
          # prefixes only its first token with ghaf.givc.appPrefix, exactly as
          # it did before the rename.
          {
            name = "fmo-onboarding-agent";
            desktopName = "FMO Onboarding Agent";
            description = "FMO Onboarding Agent";
            packages = [
              pkgs.onboarding-agent
              pkgs.fmo-onboarding
              pkgs.papirus-icon-theme
            ];
            icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/rocs.svg";
            exec = "foot /run/wrappers/bin/sudo ${pkgs.fmo-onboarding}/bin/fmo-onboarding";
          }
          {
            name = "fmo-offboarding";
            desktopName = "FMO Offboarding";
            description = "FMO Offboarding - remove registration data";
            packages = [
              pkgs.fmo-offboarding
              pkgs.papirus-icon-theme
            ];
            icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/places/user-trash.svg";
            exec = "foot /run/wrappers/bin/sudo ${pkgs.fmo-offboarding}/bin/fmo-offboarding";
          }
        ];

        extraModules = [
          inputs.self.nixosModules.docker-vm-services
          # Wrapped rather than passed as a bare `./config.nix` path. Both are
          # valid NixOS modules, but ghaf's wireguard-gui walks every app-VM's
          # extraModules with `extraMod // { vmName = ...; }`
          # (ghaf:modules/reference/services/wireguard-gui/wireguard-gui-config.nix),
          # and `//` needs an attrset - a path or a function makes it fail with
          # "expected a set but found a path", which surfaces as an unrelated
          # error about the option it was computing. Upstream's own app-VMs only
          # ever use inline attrsets, so the assumption goes unnoticed there.
          { imports = [ ./config.nix ]; }
        ];
      };

      # Device-specific USB routing, declared on the VM that uses it rather than
      # as a global rule.
      usbPassthrough = [
        {
          description = "GPS receiver for DockerVM";
          targetVm = "docker-vm";
          tag = "gps";
          allow = [
            {
              vendorId = "0403";
              productId = "6015";
              description = "FTDI FT231X USB UART to access GPS device";
            }
          ];
        }
      ];
    };
  };
}
