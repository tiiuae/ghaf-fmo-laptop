# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake.nixosModules = {
    hardware-alienware-m18-r2.imports = [
      inputs.ghaf.nixosModules.hardware-alienware-m18-r2
      ./resources/alienware-m18-r2.nix
      ./definition/external-usb.nix
    ];
    hardware-dell-latitude-7230.imports = [
      inputs.ghaf.nixosModules.hardware-dell-latitude-7230
      ./resources/dell-latitude-7230.nix
      ./definition/dell-latitude-7230.nix
      ./definition/external-usb.nix
    ];
    hardware-dell-latitude-7330-71.imports = [
      inputs.ghaf.nixosModules.hardware-dell-latitude-7330-71
      ./resources/dell-latitude-7330.nix
      ./definition/external-usb.nix
    ];
    hardware-dell-latitude-7330-72.imports = [
      inputs.ghaf.nixosModules.hardware-dell-latitude-7330-72
      ./resources/dell-latitude-7330.nix
      ./definition/external-usb.nix
    ];
    hardware-demo-tower-mk1.imports = [
      inputs.ghaf.nixosModules.hardware-demo-tower-mk1
      ./resources/demo-tower-mk1.nix
      # TODO: fix this upstream to support the usb kbd also
      #./definition/external-usb.nix
    ];
    hardware-lenovo-x1-carbon-gen11.imports = [
      inputs.ghaf.nixosModules.hardware-lenovo-x1-carbon-gen11
      ./resources/lenovo-x1-carbon-gen11.nix
      ./definition/external-usb.nix
    ];
    hardware-lenovo-x1-carbon-gen12.imports = [
      inputs.ghaf.nixosModules.hardware-lenovo-x1-carbon-gen12
      ./resources/lenovo-x1-carbon-gen12.nix
      ./definition/external-usb.nix
    ];
  };
}
