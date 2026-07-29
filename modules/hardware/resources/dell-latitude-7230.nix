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
#    Net VM:     2 vcpu   1024 MB   (ghaf default, not set here)
#    Audio VM:   2 vcpu    512 MB   (ghaf default, not set here)
#    Admin VM:   2 vcpu   1024 MB   (ghaf default, not set here)
#    Gui VM:     3 vcpu    2303 MB
#    Docker VM:  5 vcpu    2303 MB
#
# Memory ballooning is enabled in Ghaf.
#
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    sysvms.guivm = {
      mem = 2303;
      vcpu = 3;
    };

    # App VMs
    appvms = {
      docker = {
        mem = 2303;
        vcpu = 5;
        balloonRatio = 4;
      };
    };
  };
}
