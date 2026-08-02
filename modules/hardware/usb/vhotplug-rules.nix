# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# Smartcard routing for docker-vm.
#
# This stays a `prependUsbRules` entry on purpose, and it is the one rule here
# that has to be. vhotplug takes the FIRST matching rule, and the generated
# config is
#   prependUsbRules ++ usbRules ++ postpendUsbRules
# (ghaf:modules/hardware/passthrough/vhotplug.nix). Ghaf's gui-VM defaults
# already claim `interfaceClass = 11`, so a rule that does not come first loses
# the YubiKey to gui-vm. Moving this to the per-appVM `usbPassthrough` option -
# the modern mechanism, which the FTDI GPS rule in
# modules/microvm/docker/config.nix now uses - would land it in `usbRules`,
# after gui-vm's, and silently reroute the token.
#
# The cost is that this shadows ghaf's gui-VM smartcard default for the whole
# device, not just for FMO's own tokens: any class-11 device goes to docker-vm.
# That is intended (the DCI stack there is what uses them), but it is worth
# knowing before plugging in a smartcard reader meant for the desktop.
{
  config = {
    ghaf.hardware.passthrough.vhotplug.prependUsbRules = [
      {
        description = "Smartcards for DockerVM";
        targetVm = "docker-vm";
        # Tagged so the kill switch can reach it: `ghaf-kill-switch` drives
        # `vhotplugcli usb suspend|resume --tag <tag>`, and an untagged rule is
        # invisible to that tooling. The camera and bluetooth rules already
        # carry `cam` and `bt`.
        tag = "sc";
        allow = [
          {
            interfaceClass = 11;
            description = "Chip/SmartCard (e.g. YubiKey)";
          }
        ];
      }
    ];
  };
}
