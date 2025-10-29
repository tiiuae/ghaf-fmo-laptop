# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  system = "x86_64-linux";
  nixMods = inputs.self.nixosModules;
  inherit (inputs.self) lib;

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

  # Use the builder functions exported from ghaf
  mkLaptopConfiguration = inputs.ghaf.builders.mkLaptopConfiguration {
    self = inputs.ghaf;
    inherit inputs;
    inherit (inputs.ghaf) lib;
    inherit system;
  };

  mkLaptopInstaller = inputs.ghaf.builders.mkLaptopInstaller {
    self = inputs.ghaf;
    inherit (inputs.ghaf) lib;
    inherit system;
  };

  # Wrapper function to adapt to our naming convention and add versionRev
  laptop-configuration =
    machineType: variant: extraModules:
    let
      # Create base configuration with ghaf function
      baseConfig = mkLaptopConfiguration machineType variant (
        [
          {
            nixpkgs.overlays = [
              inputs.self.overlays.custom-packages
              inputs.self.overlays.own-pkgs-overlay
            ];
            system = {
              configurationRevision = versionRev;
              nixos.label = versionRev;
            };
          }
        ]
        ++ extraModules
      );
    in
    {
      hostConfig = baseConfig.hostConfiguration;
      inherit (baseConfig) package variant name;
    };

  # Wrapper function for installer to match our existing interface
  installer-config =
    name: imagePath: extraModules:
    let
      installerResult = mkLaptopInstaller name imagePath extraModules;
    in
    {
      hostConfig = installerResult.hostConfiguration;
      inherit (installerResult) name package;
    };

  installerModules = [
    (
      { config, ... }:
      {
        imports = [
          inputs.ghaf.nixosModules.common
          inputs.ghaf.nixosModules.development
          inputs.ghaf.nixosModules.reference-personalize
        ];

        users.users.nixos.openssh.authorizedKeys.keys =
          config.ghaf.reference.personalize.keys.authorizedSshKeys;
      }
    )
  ];

  # create a configuration for each live image
  target-configs = [
    (laptop-configuration "fmo-alienware-m18-r2" "debug" [
      nixMods.hardware-alienware-m18-r2
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-dell-7230" "debug" [
      nixMods.hardware-dell-latitude-7230
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-dell-7330" "debug" [
      nixMods.hardware-dell-latitude-7330
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-lenovo-x1-gen11" "debug" [
      nixMods.hardware-lenovo-x1-carbon-gen11
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-lenovo-x1-gen12" "debug" [
      nixMods.hardware-lenovo-x1-carbon-gen12
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-demo-tower-mk1" "debug" [
      nixMods.hardware-demo-tower-mk1
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    (laptop-configuration "fmo-tower-5080" "debug" [
      nixMods.hardware-tower-5080
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
      }
    ])
    #
    # Release Builds
    #
    # TODO: enable in a later release
    #
    # (laptop-configuration "fmo-alienware-m18-r2" "release" [
    #   nixMods.hardware-alienware-m18-r2
    #   nixMods.fmo-profile
    #   {
    #     ghaf.profiles.release.enable = true;
    #   }
    # ])
    # (laptop-configuration "fmo-dell-7230" "release" [
    #   nixMods.hardware-dell-latitude-7230
    #   nixMods.fmo-profile
    #   {
    #     ghaf.profiles.release.enable = true;
    #   }
    # ])
    # (laptop-configuration "fmo-dell-7330" "release" [
    #   nixMods.hardware-dell-latitude-7330
    #   nixMods.fmo-profile
    #   {
    #     ghaf.profiles.release.enable = true;
    #   }
    # ])
    # (laptop-configuration "fmo-lenovo-x1-gen11" "release" [
    #   nixMods.hardware-lenovo-x1-carbon-gen11
    #   nixMods.fmo-profile
    #   {
    #     ghaf.profiles.release.enable = true;
    #   }
    # ])

    # DAC-enabled images
    (laptop-configuration "fmo-alienware-m18-r2" "debug-dac" [
      nixMods.hardware-alienware-m18-r2
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-dell-7230" "debug-dac" [
      nixMods.hardware-dell-latitude-7230
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-dell-7330" "debug-dac" [
      nixMods.hardware-dell-latitude-7330
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-lenovo-x1-gen11" "debug-dac" [
      nixMods.hardware-lenovo-x1-carbon-gen11
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-lenovo-x1-gen12" "debug-dac" [
      nixMods.hardware-lenovo-x1-carbon-gen12
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-demo-tower-mk1" "debug-dac" [
      nixMods.hardware-demo-tower-mk1
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
    (laptop-configuration "fmo-tower-5080" "debug-dac" [
      nixMods.hardware-tower-5080
      nixMods.fmo-profile
      {
        ghaf.profiles.debug.enable = true;
        fmo.personalize.debug.enable = true;
        dockervm.enableDac = true;
      }
    ])
  ];

  # create an installer for each target
  target-installers = map (
    t: installer-config t.name inputs.self.packages.x86_64-linux.${t.name} installerModules
  ) target-configs;

  # the overall outputs. Both the live image and an installer for it.
  targets = target-configs ++ target-installers;
in
{
  flake = {
    nixosConfigurations = builtins.listToAttrs (map (t: lib.nameValuePair t.name t.hostConfig) targets);
    packages.${system} = builtins.listToAttrs (map (t: lib.nameValuePair t.name t.package) targets);
  };
}
