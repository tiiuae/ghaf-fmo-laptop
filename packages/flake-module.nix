# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake.overlays.own-pkgs-overlay = final: _prev: {
    fmo-build-helper = final.callPackage ./fmo-build-helper/default.nix { };
    fmo-onboarding = final.callPackage ./fmo-onboarding/default.nix { };
    fmo-offboarding = final.callPackage ./fmo-offboarding/default.nix { };
    fmo-set-netw-con = final.callPackage ./fmo-set-netw-con/default.nix { };
    fmo-launch-set-netw = final.callPackage ./fmo-launch-set-netw/default.nix { };
    onboarding-agent = inputs.onboarding-agent.packages.${final.stdenv.hostPlatform.system}.default;
  };
}
