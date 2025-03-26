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
#    Gui VM:     4 vcpu    8192 MB
#    Zathura VM: 1 vcpu    512 MB
#    Chrome VM:  10 vcpu    8192 MB
#    Docker VM:  10 vcpu    8192 MB
#    (Msg VM:     2 vcpu    512 MB)
#
# Memory ballooning is enabled in Ghaf.
#
{
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
      ramMb = mkForce 8192;
      cores = mkForce 10;
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
      ramMb = mkForce 8192;
      cores = mkForce 10;
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
