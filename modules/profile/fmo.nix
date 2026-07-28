# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  config,
  lib,
  ...
}:
let
  hostGlobalConfig = config.ghaf.global-config;
  ghafInputs = inputs.ghaf.inputs // {
    self = inputs.ghaf;
  };
in
{
  imports = [
    inputs.ghaf.nixosModules.disko-debug-partition
    # Declares ghaf.partitioning.verity.*, which disko-debug-partition reads
    # unconditionally. Upstream ships both together in its commonModules.
    inputs.ghaf.nixosModules.verity-release-partition
    inputs.ghaf.nixosModules.reference-appvms
    inputs.ghaf.nixosModules.reference-passthrough
    inputs.ghaf.nixosModules.reference-programs
    inputs.ghaf.nixosModules.reference-services
    inputs.ghaf.nixosModules.reference-desktop
    inputs.self.nixosModules.host
    inputs.self.nixosModules.fmo-services
    inputs.self.nixosModules.fmo-personalize
    inputs.self.nixosModules.dockervm
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

        # Every ghaf reference app-VM is mkDefault-disabled upstream, so there
        # is nothing to turn off here. The old `vms.zathura.enable = false` was
        # worse than redundant: zathura was renamed to media, and because `vms`
        # is an attrsOf submodule the stale key silently materialised a phantom
        # VM entry rather than erroring. FMO ships only the docker app-VM.
        appvm.enable = true;
      };

      logging = {
        enable = false;
        server.endpoint = "https://loki.ghaflogs.vedenemo.dev/loki/api/v1/push";
        listener.address = config.ghaf.networking.hosts.admin-vm.ipv4;
      };

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
            # TODO(upstream): "gnss0" is not defined by any ghaf hardware
            # definition, so this entry matches nothing and the GNSS receiver
            # is NOT currently passed through to the docker-VM. Every other
            # name here resolves via ghaf's shared external-devices list.
            # The fix belongs upstream, next to gps0/crazyradio0/xbox0 in
            # ghaf:modules/hardware/common/usb/external-devices.nix. Kept here
            # so the requirement is not lost when that lands.
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
