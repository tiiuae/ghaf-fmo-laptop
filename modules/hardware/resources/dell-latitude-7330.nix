# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This file specifies resource usage across Ghaf, as different
# hardware has different requirements.
#
# Dell Latitude 7330 (11th Gen Intel(R) Core(TM) i5-1145G7)
#    RAM:                  16 GB
#    Cache:                8 MB
#    Total Cores           4
#    Total Threads         8
#    Processor Base Power  12 W
#    Maximum Turbo Power   28 W
#
# Resource allocation:
#    Net VM:     2 vcpu   1024 MB   (ghaf default, not set here)
#    Audio VM:   2 vcpu    512 MB   (ghaf default, not set here)
#    Admin VM:   2 vcpu   1024 MB   (ghaf default, not set here)
#    Gui VM:     3 vcpu    6400 MB
#    Docker VM:  2 vcpu    2303 MB
#
# Memory ballooning is enabled in Ghaf.
#
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    sysvms.guivm = {
      mem = 6400;
      vcpu = 3;
    };

    # App VMs
    appvms = {
      docker = {
        mem = 2303;
        vcpu = 2;
        balloonRatio = 4;
      };
    };
  };
}
