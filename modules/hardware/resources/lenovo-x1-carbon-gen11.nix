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
#    Net VM:     1 vcpu    512 MB
#    Audio VM:   1 vcpu    384 MB
#    Admin VM:   1 vcpu    512 MB
#    Gui VM:     6 vcpu    10240 MB
#
# Memory ballooning is enabled in Ghaf.
#
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  config = {
    # Gui VM - use vmConfig for resource allocation
    ghaf.virtualization.vmConfig.guivm = {
      mem = mkForce 10240;
      vcpu = mkForce 6;
    };
  };
}
