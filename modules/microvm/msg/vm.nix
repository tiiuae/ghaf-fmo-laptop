# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  config,
  lib,
  pkgs,
  ...
}:
{
  msg = {
    # TODO Decide if msg vm should be used
    enable = false;
    borderColor = "#000000";
    applications = [ ];
    extraModules = [
      (import ./config.nix { inherit pkgs lib config; })
    ];
  };
}
