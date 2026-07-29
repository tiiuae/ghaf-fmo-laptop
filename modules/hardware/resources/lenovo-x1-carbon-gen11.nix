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
#    Net VM:     2 vcpu   1024 MB   (ghaf default, not set here)
#    Audio VM:   2 vcpu    512 MB   (ghaf default, not set here)
#    Admin VM:   2 vcpu   1024 MB   (ghaf default, not set here)
#    Gui VM:     7 vcpu    10496 MB
#    Docker VM:  4 vcpu    4352 MB
#
# Memory ballooning is enabled in Ghaf.
#
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    sysvms.guivm = {
      mem = 10496;
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
