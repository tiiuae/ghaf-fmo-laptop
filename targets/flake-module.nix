# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  system = "x86_64-linux";
  nixMods = inputs.self.nixosModules;
  inherit (inputs.ghaf) lib;

  versionRev =
    if (inputs.self ? shortRev) then
      inputs.self.shortRev
    else if (inputs.self ? dirtyShortRev) then
      inputs.self.dirtyShortRev
    else
      "unknown-dirty-rev";

  ghafInputs = inputs.ghaf.inputs // {
    self = inputs.ghaf;
  };

  mkGhafConfiguration = inputs.ghaf.builders.mkGhafConfiguration {
    self = inputs.ghaf;
    inputs = ghafInputs;
    inherit lib;
  };

  mkGhafInstaller = inputs.ghaf.builders.mkGhafInstaller {
    self = inputs.ghaf;
    inherit lib system;
  };

  fmoCommonModule = {
    nixpkgs.overlays = [
      inputs.self.overlays.custom-packages
      inputs.self.overlays.own-pkgs-overlay
    ];
    system = {
      configurationRevision = versionRev;
      nixos.label = versionRev;
    };
  };

  fmo-configuration =
    {
      name,
      hardwareModule,
      variant ? "debug",
      extraModules ? [ ],
      extraConfig ? { },
      vmConfig ? { },
    }:
    let
      baseConfig = mkGhafConfiguration {
        inherit
          name
          system
          variant
          vmConfig
          extraConfig
          ;
        profile = "laptop-x86";
        inherit hardwareModule;
        extraModules = [
          fmoCommonModule
          nixMods.fmo-profile
          { fmo.personalize.debug.enable = variant == "debug"; }
        ]
        ++ extraModules;
      };
    in
    {
      hostConfig = baseConfig.hostConfiguration;
      inherit (baseConfig) package variant name;
    };

  installer-config =
    targetName: imagePath: extraModules:
    let
      installerResult = mkGhafInstaller {
        name = targetName;
        inherit imagePath extraModules;
      };
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
          inputs.ghaf.nixosModules.givc
          inputs.ghaf.nixosModules.development
          inputs.ghaf.nixosModules.reference-personalize
        ];
        users.users.nixos.openssh.authorizedKeys.keys =
          config.ghaf.reference.personalize.keys.authorizedSshKeys;
      }
    )
  ];

  target-configs = [
    (fmo-configuration {
      name = "fmo-alienware-m18-r2";
      hardwareModule = nixMods.hardware-alienware-m18-r2;
    })
    (fmo-configuration {
      name = "fmo-dell-7230";
      hardwareModule = nixMods.hardware-dell-latitude-7230;
    })
    (fmo-configuration {
      name = "fmo-dell-7330";
      hardwareModule = nixMods.hardware-dell-latitude-7330;
    })
    (fmo-configuration {
      name = "fmo-lenovo-x1-gen11";
      hardwareModule = nixMods.hardware-lenovo-x1-carbon-gen11;
    })
    (fmo-configuration {
      name = "fmo-lenovo-x1-gen12";
      hardwareModule = nixMods.hardware-lenovo-x1-carbon-gen12;
    })
    (fmo-configuration {
      name = "fmo-demo-tower-mk1";
      hardwareModule = nixMods.hardware-demo-tower-mk1;
    })
    (fmo-configuration {
      name = "fmo-tower-5080";
      hardwareModule = nixMods.hardware-tower-5080;
    })
    # TODO: Release builds - enable in a later release
    # (fmo-configuration {
    #   name = "fmo-alienware-m18-r2";
    #   hardwareModule = nixMods.hardware-alienware-m18-r2;
    #   variant = "release";
    # })
  ];

  target-installers = map (
    t: installer-config t.name inputs.self.packages.x86_64-linux.${t.name} installerModules
  ) target-configs;

  targets = target-configs ++ target-installers;
in
{
  flake = {
    nixosConfigurations = builtins.listToAttrs (map (t: lib.nameValuePair t.name t.hostConfig) targets);
    packages.${system} = builtins.listToAttrs (map (t: lib.nameValuePair t.name t.package) targets);
  };
}
