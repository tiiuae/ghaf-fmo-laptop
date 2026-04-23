# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different requirements.
#
# Demo Tower Mk1 (AMD Ryzen Threadripper 3970X 32-Core Processor)
#    RAM:                  128 GB
#    Cache:                36 MB
#    Total Cores           32
#    Total Threads         64
#    Processor Base Power  55 W
#    Maximum Turbo Power   157 W
#
# Resource allocation:
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     16 vcpu   66048 MB
#    Docker VM:  10 vcpu   8704 MB
#
# Memory ballooning is enabled in Ghaf.
#
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    guivm = {
      mem = mkForce 66048;
      vcpu = mkForce 16;
    };

    # App VMs
    appvms = {
      docker = {
        mem = mkForce 8704;
        vcpu = mkForce 10;
        balloonRatio = mkForce 4;
      };
    };
  };
}
