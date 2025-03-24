# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkForce;
in
{
  config = {

    # USB passthrough options
    # TODO External USB devices should get picked up automatically
    # by vhotplug. These network adapters are untested, and this
    # yubikey is misidentified.
    ghaf.hardware.definition.usb.external = mkForce [
      {
        # PLX Technology, Inc. RNDIS/Ethernet Gadget
        # PLX Technology, Inc. Linux-USB Ethernet/RNDIS Gadget
        name = "mesh0";
        vendorId = "0525";
        productId = "a4a2";
      }
      {
        # Realtek Semiconductor Corp. USB 10/100/1000 LAN
        # Realtek Semiconductor Corp. RTL8153 Gigabit Ethernet Adapter
        name = "externalmesh0";
        vendorId = "0bda";
        productId = "8153";
      }
      # You may add any other yubikey device here. Alternatively, you can also
      # specify passthrough via vhotplug, however, devices are sometimes mis-
      # identified (such as this yubikey).
      {
        name = "yubikey0";
        vendorId = "1050";
        productId = "0407";
      }
    ];

  };
}
