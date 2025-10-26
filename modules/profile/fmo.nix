# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) optionals;
in
{
  imports = [
    # Ghaf imports
    inputs.ghaf.nixosModules.disko-debug-partition
    # Note: profiles-workstation is already included by the ghaf builder
    inputs.ghaf.nixosModules.reference-appvms
    inputs.ghaf.nixosModules.reference-programs
    inputs.ghaf.nixosModules.reference-services
    inputs.ghaf.nixosModules.reference-desktop

    # FMO imports
    inputs.self.nixosModules.host
    inputs.self.nixosModules.fmo-services
    inputs.self.nixosModules.fmo-personalize
  ];

  config = {

    ghaf = {

      # Ghaf platform profile
      profiles = {
        laptop-x86 = {
          enable = true;
          netvmExtraModules = [
            # Ghaf imports
            inputs.ghaf.nixosModules.reference-services

            # FMO imports
            inputs.self.nixosModules.netvm
            inputs.self.nixosModules.fmo-services
            inputs.self.nixosModules.fmo-personalize
          ];
          guivmExtraModules = [
            # Ghaf imports
            inputs.ghaf.nixosModules.reference-programs

            # FMO imports
            inputs.self.nixosModules.fmo-personalize
            inputs.self.nixosModules.guivm
          ];
        };
        graphics = {
          idleManagement.enable = false;
          allowSuspend = false;
        };
      };

      # Enable logging
      logging = {
        enable = false;
        server.endpoint = "https://loki.ghaflogs.vedenemo.dev/loki/api/v1/push";
        listener.address = config.ghaf.networking.hosts.admin-vm.ipv4;
      };

      graphics = {
        labwc = {
          autologinUser = lib.mkForce null;
        };
      };

      # Enable shared directories for the selected VMs
      virtualization.microvm-host.sharedVmDirectory.vms =
        optionals
          (
            config.ghaf.virtualization.microvm.appvm.enable
            && config.ghaf.virtualization.microvm.appvm.vms.chrome.enable
          )
          [
            "chrome-vm"
          ];

      virtualization.microvm.appvm = {
        enable = true;
        vms = {
          chrome.enable = false;
          zathura.enable = false;
        }
        // (import ../microvm/docker/vm.nix { inherit pkgs lib config; })
        // (import ../microvm/msg/vm.nix { inherit pkgs lib config; });
      };

      hardware.passthrough.VMs = {
        gui-vm.permittedDevices = [
          "cam0"
          "fpr0"
          "gps0"
          "usbKBD"
        ];
        docker-vm.permittedDevices = [
          "crazyradio0"
          "crazyradio1"
          "gnss0"
          "xbox0"
          "xbox1"
          "crazyflie0"
          "xbox2"
        ];
        audio-vm.permittedDevices = [ "bt0" ];
      };
      # Content
      reference = {
        appvms.enable = true;
        desktop.applications.enable = true;

        services = {
          enable = true;
          google-chromecast.enable = false;
        };
      };

      # TODO: this is the debug partitioning for the ghaf
      # it allows read and write. Production should use the read-only version
      # that is coming with dm-verity
      partitioning.disko.enable = true;

      # Enable power management
      services.power-manager.enable = true;
    };
  };
}
