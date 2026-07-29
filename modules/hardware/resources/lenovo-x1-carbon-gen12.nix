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
#    Net VM:     2 vcpu   1024 MB   (ghaf default, not set here)
#    Audio VM:   2 vcpu    512 MB   (ghaf default, not set here)
#    Admin VM:   2 vcpu   1024 MB   (ghaf default, not set here)
#    Gui VM:     7 vcpu    8448 MB
#    Docker VM:  4 vcpu    4352 MB
#
# Memory ballooning is enabled in Ghaf.
#
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    sysvms.guivm = {
      mem = 8448;
      vcpu = 7;
    };

    # App VMs
    appvms = {
      docker = {
        mem = 4352;
        vcpu = 4;
        balloonRatio = 4;
      };
    };
  };
}
