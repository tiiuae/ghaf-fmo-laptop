# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  system = "x86_64-linux";

  mkFmoLaptopConfiguration =
    hardware-module: profile-module:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        hardware-module
        profile-module
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
              inputs.self.overlays.own-pkgs-overlay
            ];

          };
        }
      ];
    };
in
{
  flake = {
    nixosConfigurations = {
      fmo-dell-7230 = mkFmoLaptopConfiguration inputs.self.nixosModules.hardware-dell-latitude-7230 inputs.self.nixosModules.fmo-profile;
      fmo-alienware = mkFmoLaptopConfiguration inputs.self.nixosModules.hardware-alienware-m18-r2 inputs.self.nixosModules.fmo-profile;
    };
    packages.${system} = {
      fmo-dell-7230 = inputs.self.nixosConfigurations.fmo-dell-7230.config.system.build.diskoImages;
      fmo-alienware = inputs.self.nixosConfigurations.fmo-alienware.config.system.build.diskoImages;
    };
  };
}
