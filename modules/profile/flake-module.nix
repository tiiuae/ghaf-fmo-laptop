# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake.nixosModules = {
    fmo-profile.imports = [
      (import ./fmo.nix { inherit inputs; })
    ];
    fmo-personalize.imports = [
      inputs.ghaf.nixosModules.reference-personalize
      ./personalize.nix
      {
        fmo.personalize.debug.enable = true;
        ghaf.reference.personalize.keys.enable = true;
      }
    ];
  };
}
