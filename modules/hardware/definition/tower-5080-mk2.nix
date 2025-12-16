# Copyright 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  config = {

    ghaf.hardware.definition.network.pciDevices = mkForce [
      {
        # Network controller: Intel Corporation Raptor Lake-S PCH CNVi WiFi (rev 11)
        name = "wlp0s5f0";
        path = "0000:00:14.3";
        vendorId = "8086";
        productId = "7a70";
      }
      {
        # Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8125 2.5GbE Controller
        name = "eth0";
        path = "0000:06:00.0";
        vendorId = "10ec";
        productId = "8125";
      }
    ];
  };
}
