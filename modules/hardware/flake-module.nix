# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, lib, ... }:
{
  flake.nixosModules = {
    hardware-alienware-m18-r2.imports = [
      inputs.ghaf.nixosModules.hardware-alienware-m18-r2
      ./resources/alienware-m18-r2.nix
      ./usb
    ];
    hardware-dell-latitude-7230.imports = [
      inputs.ghaf.nixosModules.hardware-dell-latitude-7230
      ./resources/dell-latitude-7230.nix
      ./usb
    ];
    hardware-dell-latitude-7330.imports = [
      inputs.ghaf.nixosModules.hardware-dell-latitude-7330
      ./resources/dell-latitude-7330.nix
      ./usb
    ];
    hardware-demo-tower-mk1.imports = [
      inputs.ghaf.nixosModules.hardware-demo-tower-mk1
      ./resources/demo-tower-mk1.nix
      # TODO: fix this upstream to support the usb kbd also
      #./definition/external-usb.nix
    ];
    hardware-tower-5080.imports = [
      inputs.ghaf.nixosModules.hardware-tower-5080
      ./resources/tower-5080.nix
      {
        ghaf.hardware.definition.network.pciDevices = lib.mkForce [ ];
      }
    ];
    hardware-lenovo-x1-carbon-gen11.imports = [
      inputs.ghaf.nixosModules.hardware-lenovo-x1-carbon-gen11
      ./resources/lenovo-x1-carbon-gen11.nix
      ./usb
    ];
    hardware-lenovo-x1-carbon-gen12.imports = [
      inputs.ghaf.nixosModules.hardware-lenovo-x1-carbon-gen12
      ./resources/lenovo-x1-carbon-gen12.nix
      ./usb
    ];
  };
}
