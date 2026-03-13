# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different requirements.
#
# Alienware m18 R2 (Intel(R) Core(TM) i9-14900HX)
#    RAM:                  64 GB
#    Cache:                36 MB
#    Total Cores           24
#    Performance-cores     16
#    Efficient-cores       8
#    Total Threads         32
#    Processor Base Power  55 W
#    Maximum Turbo Power   157 W
#
# Resource allocation:
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     12 vcpu   16896 MB
#    Docker VM:  10 vcpu   4608 MB
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
      mem = mkForce 16896;
      vcpu = mkForce 12;
    };

    # App VMs
    appvms = {
      docker = {
        mem = mkForce 4608;
        vcpu = mkForce 10;
        balloonRatio = mkForce 4;
      };
    };
  };
}
