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
#    Gui VM:     4 vcpu    4096 MB
#    Zathura VM: 1 vcpu    512 MB
#    Chrome VM:  8 vcpu    4096 MB
#    Docker VM:  8 vcpu    4096 MB
#    (Msg VM:     2 vcpu    512 MB)
#
# Memory ballooning is enabled in Ghaf.
#
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkForce
    ;
in
{
  config = {

    # Gui VM
    microvm.vms.gui-vm.config.config.microvm = {
      mem = mkForce 8192;
      vcpu = mkForce 4;
    };

    # Docker VM
    ghaf.virtualization.microvm.appvm.vms.docker = {
      ramMb = mkForce 4096;
      cores = mkForce 8;
      balloonRatio = mkForce 4;
    };

    # Msg VM
    ghaf.virtualization.microvm.appvm.vms.msg = {
      ramMb = mkForce 1024;
      cores = mkForce 4;
      balloonRatio = mkForce 4;
    };

    # Chrome VM
    ghaf.virtualization.microvm.appvm.vms.chrome = {
      ramMb = mkForce 4096;
      cores = mkForce 8;
      balloonRatio = mkForce 4;
    };

    # Zathura VM
    ghaf.virtualization.microvm.appvm.vms.zathura = {
      ramMb = mkForce 512;
      cores = mkForce 1;
      balloonRatio = mkForce 2;
    };

  };
}
