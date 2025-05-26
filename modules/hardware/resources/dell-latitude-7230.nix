# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different requirements.
#
# Dell Latitude 7230 (12th Gen Intel(R) Core(TM) i5-1240U)
#    RAM:                  7936 MiB
#    Cache:                12 MB
#    Total Cores           10
#    Performance-cores     2
#    Efficient-cores       8
#    Total Threads         12
#    Processor Base Power  9 W
#    Maximum Turbo Power   29 W
#
# Resource allocation:
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     2 vcpu    2047 MB
#    Zathura VM: 1 vcpu    512 MB
#    Chrome VM:  4 vcpu    2047 MB
#    Docker VM:  4 vcpu    2047 MB
#    (Msg VM:     2 vcpu    512 MB)
#
# Memory ballooning is enabled in Ghaf.
#
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  config = {

    # Gui VM
    microvm.vms.gui-vm.config.config.microvm = {
      mem = mkForce 2047;
      vcpu = mkForce 2;
    };

    ghaf.virtualization.microvm.appvm.vms = {
      # Docker VM
      docker = {
        ramMb = mkForce 2047;
        cores = mkForce 4;
        balloonRatio = mkForce 4;
      };

      # Msg VM
      msg = {
        ramMb = mkForce 512;
        cores = mkForce 2;
        balloonRatio = mkForce 4;
      };

      # Chrome VM
      chrome = {
        ramMb = mkForce 2047;
        cores = mkForce 4;
        balloonRatio = mkForce 4;
      };

      # Zathura VM
      zathura = {
        ramMb = mkForce 512;
        cores = mkForce 1;
        balloonRatio = mkForce 2;
      };
    };
  };
}
