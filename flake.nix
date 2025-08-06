# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  description = "A Ghaf-based FMO laptop";

  nixConfig = {
    substituters = [
      "https://ghaf-dev.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-substituters = [
      "https://ghaf-dev.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "ghaf-dev.cachix.org-1:S3M8x3no8LFQPBfHw1jl6nmP8A7cVWKntoMKN3IsEQY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];

    allow-import-from-derivation = false;
  };

  inputs = {

    # Pinned to the version that ghaf is currently pinned to.
    nixpkgs = {
      url = "github:tiiuae/nixpkgs/fix-qemu-rebase";
    };

    ghaf = {
      #url = "flake:mylocalghaf";
      url = "github:tiiuae/ghaf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    onboarding-agent = {
      url = "git+ssh://git@github.com/tiiuae/onboarding-agent";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "ghaf/flake-utils";
      };
    };

    device-assembly-toolset = {
      url = "git+ssh://git@github.com/tiiuae/device_assembly_toolset?ref=feature/pmc-agent";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "ghaf/flake-utils";
      };
    };

    ###
    # Flake and repo structuring configurations
    ###
    # Format all the things
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    # To ensure that checks are run locally to enforce cleanliness
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-root.url = "github:srid/flake-root";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ###
    ### End of Flake and repo structuring configurations
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      inherit (inputs.ghaf) lib;
    in
    flake-parts.lib.mkFlake
      {
        inherit inputs;
        specialArgs = { inherit lib; };
      }
      {
        systems = [
          "x86_64-linux"
        ];
        imports = [
          ./modules/flake-module.nix
          ./nix/flake-module.nix
          ./overlays/flake-module.nix
          ./targets/flake-module.nix
          ./packages/flake-module.nix
        ];
        flake.lib = lib;
      };
}
