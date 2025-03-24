# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0

{ inputs, lib, ... }:
{
  imports = [
    inputs.devshell.flakeModule
  ];
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      fmo-build-helper = pkgs.callPackage ../packages/fmo-build-helper/default.nix { };
    in
    {
      devshells = {
        # the main developer environment
        default = {
          devshell = {
            name = "Ghaf-fmo devshell";
            meta.description = "ghaf-fmo development environment";
            packages =
              [
                pkgs.jq
                pkgs.nix-eval-jobs
                pkgs.nix-fast-build
                pkgs.nix-output-monitor
                pkgs.nix-tree
                pkgs.nixVersions.latest
                pkgs.reuse
                pkgs.cachix
                config.treefmt.build.wrapper
                fmo-build-helper
              ]
              ++ lib.attrValues config.treefmt.build.programs # make all the treefmt packages available
              ++ config.pre-commit.settings.enabledPackages;

            startup.hook.text = config.pre-commit.installationScript;
          };
          commands = [
            {
              help = "Format";
              name = "format-repo";
              command = "treefmt";
              category = "checker";
            }
            {
              help = "Check license";
              name = "check-license";
              command = "reuse lint";
              category = "linters";
            }
            {
              help = "FMO nixos-rebuild command, uses proxy jump";
              name = "fmo-rebuild";
              command = "fmo-build-helper $@";
              category = "builder";
            }
          ];
        };
      };
    };
}
