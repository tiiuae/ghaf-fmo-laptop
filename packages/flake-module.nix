# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake.overlays.own-pkgs-overlay = final: _prev: {
    fmo-build-helper = final.callPackage ./fmo-build-helper/default.nix { };
    fmo-onboarding = final.callPackage ./fmo-onboarding/default.nix { };
    fmo-offboarding = final.callPackage ./fmo-offboarding/default.nix { };
    onboarding-agent = inputs.onboarding-agent.packages.${final.stdenv.hostPlatform.system}.default;
    inherit (inputs.device-assembly-toolset.packages.${final.stdenv.hostPlatform.system}) device-assembly-agent;
  };
}
