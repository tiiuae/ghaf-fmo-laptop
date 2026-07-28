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
      system,
      ...
    }:
    let
      # Upstream's helper is a superset of the one this repo used to carry:
      # same <target-ip> <flake-target> [opts] contract, plus --force-local /
      # --force-remote / --insecure, an nvd diff of the old and new system, and
      # a `switch` that survives the SSH connection dropping.
      ghaf-build-helper = inputs.ghaf.packages.${system}.ghaf-build-helper;
    in
    {
      devshells = {
        # the main developer environment
        default = {
          devshell = {
            name = "Ghaf-fmo devshell";
            meta.description = "ghaf-fmo development environment";
            packages = [
              pkgs.just
              pkgs.jq
              pkgs.nix-eval-jobs
              pkgs.nix-fast-build
              pkgs.nix-output-monitor
              pkgs.nix-tree
              pkgs.nixVersions.latest
              pkgs.reuse
              pkgs.cachix
              pkgs.coreutils
              config.treefmt.build.wrapper
              ghaf-build-helper
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
              command = "ghaf-build-helper $@";
              category = "builder";
            }
          ];
        };
      };
    };
}
