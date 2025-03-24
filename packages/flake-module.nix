# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake.overlays.own-pkgs-overlay = final: _prev: {
    fmo-build-helper = final.callPackage ./fmo-build-helper/default.nix { };
    fmo-registration = final.callPackage ./fmo-registration/default.nix { };
    registration-agent = inputs.registration-agent.packages.${final.stdenv.hostPlatform.system}.default;
  };
}
