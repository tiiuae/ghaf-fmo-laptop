# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different capabilities.
#
# Lenovo X1 gen12 (Intel(R) Core(TM) ultra 7 155U)
#    RAM:                       32 GB
#    Cache:                     12 MB
#    Total Cores                12
#    Performance-cores           2
#    Efficient-cores             8
#    Low Power Efficient-cores   2
#    Total Threads              14
#    Processor Base Power       15 W
#    Maximum Turbo Power        57 W
#
# Resource allocation:
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     6 vcpu    8192 MB
#    Docker VM:  4 vcpu    4096 MB
#    Msg VM:     1 vcpu    512 MB
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
      mem = mkForce 8192;
      vcpu = mkForce 6;
    };

    # App VMs
    appvms = {
      docker = {
        mem = mkForce 4096;
        vcpu = mkForce 4;
        balloonRatio = mkForce 4;
      };
      msg = {
        mem = mkForce 512;
        vcpu = mkForce 1;
        balloonRatio = mkForce 4;
      };
    };
  };
}
