# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different requirements.
#
# Tower 5080 (Intel® Core™ i9 processor 14900HX, NVIDIA GeForce RTX 5080)
#    RAM:                  192 GB
#    Cache:                36 MB
#    Total Cores           32
#    Total Threads         32
#    Processor Base Power  55 W
#    Maximum Turbo Power   157 W
#
# Resource allocation: TBD
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     14 vcpu   65536 MB
#    Docker VM:  8 vcpu    8192 MB
#    Msg VM:     4 vcpu    1024 MB
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
      mem = mkForce 65536;
      vcpu = mkForce 14;
    };

    # App VMs
    appvms = {
      docker = {
        mem = mkForce 8192;
        vcpu = mkForce 8;
        balloonRatio = mkForce 4;
      };
      msg = {
        mem = mkForce 1024;
        vcpu = mkForce 4;
        balloonRatio = mkForce 4;
      };
    };
  };
}
