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

  # extraModules is a first-level argument: the installer NixOS system is
  # evaluated once here and shared by every target's ISO.
  mkGhafInstaller = inputs.ghaf.builders.mkGhafInstaller {
    self = inputs.ghaf;
    inherit lib system;
    extraModules = installerModules;
  };

  # The same installer, delivered over the network instead of on a USB stick.
  # It gets the same installerModules as the ISO, which is what keeps the two
  # behaving identically. Unlike the ISO it does not take an imagePath - the
  # image is fetched over HTTP at install time - so the per-target outputs are
  # linkFarms over one shared kernel and initrd and cost nothing to add.
  mkGhafNetbootInstaller = inputs.ghaf.builders.mkGhafNetbootInstaller {
    self = inputs.ghaf;
    inherit lib system;
    extraModules = installerModules;
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
      inherit (baseConfig)
        extendHost
        extendVm
        getVmConfig
        buildSysupdateImage
        ;
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
        # The installer is what enrolls Secure Boot keys onto the target, so an
        # installer built without this can only ever produce machines that
        # cannot verify their own boot chain - and nothing reports that.
        ghaf.host.secureboot.enable = true;
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
    t:
    mkGhafInstaller {
      inherit (t) name;
      imagePath = inputs.self.packages.${system}.${t.name};
    }
  ) target-configs;

  # No imagePath here on purpose: the netboot installer fetches the image at
  # install time from whatever URL the server hands it, so it does not depend
  # on the target's image being built first. The default imageUrl defers to
  # iPXE's DHCP-provided ${next-server}, which keeps site-specific addresses
  # out of the repo.
  target-netboot-installers = map (t: mkGhafNetbootInstaller { inherit (t) name; }) target-configs;
in
{
  flake = {
    # Installers are packages only: mkGhafInstaller returns { name; package; }
    # and has no per-installer NixOS configuration to expose. The same is true
    # of the netboot installers.
    nixosConfigurations = builtins.listToAttrs (
      map (t: lib.nameValuePair t.name t.hostConfig) target-configs
    );
    packages.${system} = builtins.listToAttrs (
      map (t: lib.nameValuePair t.name t.package) (
        target-configs ++ target-installers ++ target-netboot-installers
      )
    );
  };
}
