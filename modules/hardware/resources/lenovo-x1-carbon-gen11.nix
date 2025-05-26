# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different capabilities.
#
# Lenovo X1 gen11 (Intel(R) Core(TM) i7-1355U)
#    RAM:                  32 GB
#    Cache:                12 MB
#    Total Cores           10
#    Performance-cores     2
#    Efficient-cores       8
#    Total Threads         12
#    Processor Base Power  15 W
#    Maximum Turbo Power   55 W
#
# Resource allocation:
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     6 vcpu    8192 MB
#    Zathura VM: 1 vcpu    512 MB
#    Chrome VM:  2 vcpu    4096 MB
#    Docker VM:  4 vcpu    4096 MB
#    (Msg VM:    1 vcpu    512 MB)
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
      mem = mkForce 10240;
      vcpu = mkForce 6;
    };

    ghaf.virtualization.microvm.appvm.vms = {
      # Docker VM
      docker = {
        ramMb = mkForce 4096;
        cores = mkForce 4;
        balloonRatio = mkForce 4;
      };

      # Msg VM
      msg = {
        ramMb = mkForce 512;
        cores = mkForce 1;
        balloonRatio = mkForce 4;
      };

      # Chrome VM
      chrome = {
        ramMb = mkForce 4096;
        cores = mkForce 2;
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
