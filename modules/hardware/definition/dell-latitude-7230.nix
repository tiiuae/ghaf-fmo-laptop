# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  config = {

    # USB passthrough options
    # TODO Fix this in ghaf, and unify mechanism for USB passthrough
    ghaf.hardware.definition.usb.devices = mkForce [
      {
        name = "bt0";
        vendorId = "8087";
        productId = "0033";
      }
      {
        name = "gnss0";
        vendorId = "1546";
        productId = "01a9";
      }
    ];
  };
}
