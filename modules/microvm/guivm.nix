# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  lib,
  ...
}:
{
  config = {
    # Limit memory
    microvm.mem = lib.mkForce 1024;

    ghaf.reference.services.ollama = lib.mkForce false;
    microvm.qemu.extraArgs = [
      "-drive"
      "file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd,if=pflash,unit=0,readonly=true"
      "-drive"
      "file=${pkgs.OVMF.fd}/FV/OVMF_VARS.fd,if=pflash,unit=1,readonly=true"
    ];
  };
}
