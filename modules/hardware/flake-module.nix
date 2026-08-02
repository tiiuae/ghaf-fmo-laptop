# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# FMO hardware modules extend ghaf's hardware modules with:
# - USB passthrough configuration
# - Resource overrides (where needed)
#
# The four Intel laptops build on upstream's GENERIC `hardware-intel-laptop`
# rather than the per-machine `hardware-<model>` modules, because the per-machine
# ones are incomplete on their own: upstream carries their passthrough fix-ups in
# its own target blocks (targets/laptop/flake-module.nix), which this repo does
# not share. Importing the hardware module alone therefore silently omits them.
#
# The Alienware and both towers deliberately stay on their per-machine modules;
# see the comments at each of them below.
#
{ inputs, lib, ... }:
{
  flake.nixosModules = {
    # Stays per-machine: the wired NIC is a discrete Realtek 10ec:5000 on its own
    # bus, and its net-vm driver comes from this module's netvm.extraModules.
    # hardware-intel-laptop only loads iwlwifi and e1000e in net-vm, so the wired
    # NIC would stop working. Its IOMMU grouping is fine as-is.
    hardware-alienware-m18-r2.imports = [
      inputs.ghaf.nixosModules.hardware-alienware-m18-r2
      ./resources/alienware-m18-r2.nix
      ./usb
    ];
    hardware-dell-latitude-7230.imports = [
      inputs.ghaf.nixosModules.hardware-intel-laptop
      ./resources/dell-latitude-7230.nix
      ./usb
    ];
    hardware-dell-latitude-7330.imports = [
      inputs.ghaf.nixosModules.hardware-intel-laptop
      ./resources/dell-latitude-7330.nix
      ./usb
    ];
    # Stays per-machine: AMD platform needing tpm2 forced off and nvidia-setup,
    # neither of which hardware-intel-laptop provides - and it blacklists
    # nouveau/nvidia on the host, which is wrong for a discrete-GPU tower.
    hardware-demo-tower-mk1.imports = [
      inputs.ghaf.nixosModules.hardware-demo-tower-mk1
      ./resources/demo-tower-mk1.nix
      # TODO: fix upstream to support usb kbd
    ];
    # Stays per-machine, same tpm2/nvidia reasons as demo-tower-mk1. The mkForce
    # below is this repo's hand-rolled version of what intel-laptop does
    # generically; revisit it if this board ever moves to the generic module.
    hardware-tower-5080.imports = [
      inputs.ghaf.nixosModules.hardware-tower-5080
      ./resources/tower-5080.nix
      ./usb
      { ghaf.hardware.definition.network.pciDevices = lib.mkForce [ ]; }
    ];
    hardware-lenovo-x1-carbon-gen11.imports = [
      inputs.ghaf.nixosModules.hardware-intel-laptop
      ./resources/lenovo-x1-carbon-gen11.nix
      ./usb
    ];
    hardware-lenovo-x1-carbon-gen12.imports = [
      inputs.ghaf.nixosModules.hardware-intel-laptop
      ./resources/lenovo-x1-carbon-gen12.nix
      ./usb
    ];
  };
}
