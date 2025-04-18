# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
#TODO: remove this file once the config builder is exported from ghaf.
{ inputs, ... }:
let
  system = "x86_64-linux";

  # The versionRev is used to identify the current version of the configuration.
  # rev is used when there is a clean repo
  # dirtyRev is used when there are uncommitted changes
  # if building in a rebased ci pre-merge check the state will be unknown.
  versionRev =
    if (inputs.self ? shortRev) then
      inputs.self.shortRev
    else if (inputs.self ? dirtyShortRev) then
      inputs.self.dirtyShortRev
    else
      "unknown-dirty-rev";

  mkFmoLaptopConfiguration =
    name: extraModules:
    let
      hostConfig = inputs.nixpkgs.lib.nixosSystem {
        modules = [
          {
            nixpkgs = {
              hostPlatform = { inherit system; };

              config.allowUnfree = true;

              overlays = [
                inputs.ghaf.overlays.default
                inputs.self.overlays.custom-packages
                inputs.self.overlays.own-pkgs-overlay
              ];
            };
            system = {
              configurationRevision = versionRev;
              nixos.label = versionRev;
            };
          }
        ] ++ extraModules;
      };
    in
    {
      inherit hostConfig;
      inherit name;
      package = hostConfig.config.system.build.diskoImages;
    };
in
mkFmoLaptopConfiguration
