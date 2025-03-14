# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  description = "A Ghaf-based FMO laptop";

  nixConfig = {
    substituters = [
      "https://prod-cache.vedenemo.dev"
      "https://cache.ssrcdevops.tii.ae"
      "https://ghaf-dev.cachix.org"
      "https://cache.nixos.org/"
    ];
    extra-trusted-substituters = [
      "https://prod-cache.vedenemo.dev"
      "https://cache.ssrcdevops.tii.ae"
      "https://ghaf-dev.cachix.org"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "prod-cache.vedenemo.dev~1:JcytRNMJJdYJVQCYwLNsrfVhct5dhCK2D3fa6O1WHOI="
      "cache.ssrcdevops.tii.ae:oOrzj9iCppf+me5/3sN/BxEkp5SaFkHfKTPPZ97xXQk="
      "ghaf-dev.cachix.org-1:S3M8x3no8LFQPBfHw1jl6nmP8A7cVWKntoMKN3IsEQY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];

    allow-import-from-derivation = false;
  };

  inputs = {

    #TODO: this needs to be pinned to the version that ghaf is currently pinned to.
    # rather painful. though it can be pinned to official releases this way.
    nixpkgs = {
      url = "github:NixOS/nixpkgs?rev=73cf49b8ad837ade2de76f87eb53fc85ed5d4680";
    };

    ghaf = {
      url = "github:tiiuae/ghaf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    givc = {
      url = "github:tiiuae/ghaf-givc";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        devshell.follows = "devshell";
      };
    };

    ctrl-panel = {
      url = "github:tiiuae/ghaf-ctrl-panel/555a414a5d50eed7f17e7f45221eba0261c40dc6";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        crane.follows = "givc/crane";
      };
    };

    registration-agent = {
      url = "git+ssh://git@github.com/tiiuae/registration-agent-laptop";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "ctrl-panel/flake-utils";
      };
    };

    # Pin the version until we can merge the changes upstream
    # TODO: we do not have access to manage the upstream repo
    fmo-tool = {
      url = "github:tiiuae/fmo-tool/119afdcf908dad61ae862c0efd8d148d8d8580ce";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "ctrl-panel/flake-utils";
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

    # Random stuff?!? TODO why is this required
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    # Other stuff due to overlay in builder
    # TODO: this should be removed if the makeScope takes care of it.
    ghafpkgs = {
      url = "github:tiiuae/ghafpkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        crane.follows = "givc/crane";
        devshell.follows = "devshell";
      };
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];
      imports = [
        ./modules/flake-module.nix
        ./nix/flake-module.nix
        ./overlays/flake-module.nix
        ./profile/flake-module.nix
        ./targets/flake-module.nix
      ];
    };
}
