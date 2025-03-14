# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  system = "x86_64-linux";
in
{
  flake = {
    nixosConfigurations = {
      fmo-laptop = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.ghaf.nixosModules.hardware-dell-latitude-7230
          inputs.self.nixosModules.fmo-profile

          # TODO Move this in ghaf
          {
            ghaf.profiles.debug.enable = true;

            nixpkgs = {
              hostPlatform = { inherit system; };

              config = {
                allowUnfree = true;
                permittedInsecurePackages = [
                  "jitsi-meet-1.0.8043"
                ];
              };

              overlays = [
                inputs.ghaf.overlays.default
                inputs.self.overlays.custom-packages
              ];

            };
          }
        ];
      };
    };
    packages.${system} = {
      fmo-laptop = inputs.self.nixosConfigurations.fmo-laptop.config.system.build.diskoImages;
    };
  };
}
