# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) optionals;
  hostGlobalConfig = config.ghaf.global-config;
  ghafInputs = inputs.ghaf.inputs // {
    self = inputs.ghaf;
  };
in
{
  imports = [
    inputs.ghaf.nixosModules.disko-debug-partition
    inputs.ghaf.nixosModules.reference-appvms
    inputs.ghaf.nixosModules.reference-passthrough
    inputs.ghaf.nixosModules.reference-programs
    inputs.ghaf.nixosModules.reference-services
    inputs.ghaf.nixosModules.reference-desktop
    inputs.self.nixosModules.host
    inputs.self.nixosModules.fmo-services
    inputs.self.nixosModules.fmo-personalize
    inputs.self.nixosModules.dockervm
    inputs.self.nixosModules.msgvm
  ];

  config = {
    fmo.appvms.docker.enable = true;

    ghaf = {
      profiles = {
        laptop-x86.enable = true;
        graphics.idleManagement.enable = false;
      };

      # Enable local user creation in the first-boot wizard
      users.profile.homed-user.enable = true;

      services = {
        power-manager = {
          enable = true;
          suspend.enable = false;
        };
        kill-switch.enable = true;
      };

      virtualization.microvm = {
        guivm.evaluatedConfig = config.ghaf.profiles.laptop-x86.guivmBase.extendModules {
          modules = [
            inputs.ghaf.nixosModules.reference-services
            inputs.ghaf.nixosModules.reference-programs
            inputs.ghaf.nixosModules.reference-personalize
            inputs.ghaf.nixosModules.guivm-desktop-features
            inputs.self.nixosModules.fmo-personalize
            inputs.self.nixosModules.guivm
            { ghaf.reference.personalize.keys.enable = true; }
          ]
          ++ lib.ghaf.vm.applyVmConfig {
            inherit config;
            vmName = "guivm";
          };
          specialArgs = lib.ghaf.vm.mkSpecialArgs {
            inherit lib;
            inputs = ghafInputs;
            globalConfig = hostGlobalConfig;
            hostConfig = lib.ghaf.vm.mkHostConfig {
              inherit config;
              vmName = "gui-vm";
            };
          };
        };

        adminvm.evaluatedConfig = config.ghaf.profiles.laptop-x86.adminvmBase;
        audiovm.evaluatedConfig = config.ghaf.profiles.laptop-x86.audiovmBase.extendModules {
          modules = lib.ghaf.vm.applyVmConfig {
            inherit config;
            vmName = "audiovm";
          };
        };

        netvm.evaluatedConfig = config.ghaf.profiles.laptop-x86.netvmBase.extendModules {
          modules = [
            inputs.ghaf.nixosModules.reference-services
            inputs.ghaf.nixosModules.reference-personalize
            inputs.self.nixosModules.netvm-services
            inputs.self.nixosModules.netvm
            inputs.self.nixosModules.fmo-personalize
            { ghaf.reference.personalize.keys.enable = true; }
          ]
          ++ lib.ghaf.vm.applyVmConfig {
            inherit config;
            vmName = "netvm";
          };
        };

        appvm = {
          enable = true;
          vms = {
            chrome.enable = false;
            zathura.enable = false;
          };
        };
      };

      logging = {
        enable = false;
        server.endpoint = "https://loki.ghaflogs.vedenemo.dev/loki/api/v1/push";
        listener.address = config.ghaf.networking.hosts.admin-vm.ipv4;
      };

      virtualization.microvm-host.sharedVmDirectory.vms = optionals (
        config.ghaf.virtualization.microvm.appvm.enable
        && config.ghaf.virtualization.microvm.appvm.vms.chrome.enable
      ) [ "chrome-vm" ];

      hardware.passthrough = {
        mode = "dynamic";

        VMs = {
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

        usb.guivmRules = lib.mkOptionDefault [
          {
            description = "Fingerprint Readers for GUIVM";
            targetVm = "gui-vm";
            allow = config.ghaf.reference.passthrough.usb.fingerprintReaders;
          }
          {
            description = "Internal Webcams for GUIVM";
            targetVm = "gui-vm";
            tag = "cam";
            allow = config.ghaf.reference.passthrough.usb.internalWebcams;
          }
        ];
      };

      reference = {
        appvms.enable = true;
        desktop.applications.enable = true;
        services = {
          enable = true;
          google-chromecast.enable = false;
        };
      };

      partitioning.disko.enable = true;

      storage.encryption = {
        enable = true;
        deferred = true;
      };
    };
  };
}
