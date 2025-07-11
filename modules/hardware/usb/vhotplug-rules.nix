# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config = {
    # TODO: Cleanup VM specific rules once vhotplug module
    # have support for it
    ghaf.hardware.usb.vhotplug.prependRules = [
      {
        name = "DockerVM";
        qmpSocket = "/var/lib/microvms/docker-vm/docker-vm.sock";
        usbPassthrough = [
          {
            class = 11;
            description = "Chip/SmartCard (e.g. YubiKey)";
          }
          {
            vendorId = "0403";
            productId = "6015";
            description = "FTDI FT231X USB UART to access GPS device";
          }
        ];
      }
    ];
  };
}
