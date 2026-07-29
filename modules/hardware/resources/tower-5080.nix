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
#    Net VM:     2 vcpu   1024 MB   (ghaf default, not set here)
#    Audio VM:   2 vcpu    512 MB   (ghaf default, not set here)
#    Admin VM:   2 vcpu   1024 MB   (ghaf default, not set here)
#    Gui VM:     16 vcpu   66048 MB
#    Docker VM:  10 vcpu   8704 MB
#
# Memory ballooning is enabled in Ghaf.
#
{
  config.ghaf.virtualization.vmConfig = {
    # Gui VM
    sysvms.guivm = {
      mem = 66048;
      vcpu = 16;
    };

    # App VMs
    appvms = {
      docker = {
        mem = 8704;
        vcpu = 10;
        balloonRatio = 4;
      };
    };
  };
}
