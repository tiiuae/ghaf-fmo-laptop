# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ config, lib, ... }:
let
  cfg = config.fmo.personalize.debug;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.fmo.personalize.debug = {
    enable = mkEnableOption "Enable the FMO debug personalization module.";

    authorizedSshKeys = mkOption {
      description = "List of authorized ssh keys for the development team.";
      type = types.listOf types.str;
      default = [
        # Add your SSH Public Keys here
        # NOTE: adding your pub ssh key here will make accessing and "nixos-rebuild switching" development mode
        # builds easy but still secure. Given that you protect your private keys. Do not share your keypairs across hosts.
        #
        # Shared authorized keys access poses a minor risk for developers in the same network (e.g. office) cross-accessing
        # each others development devices if:
        # - the ip addresses from dhcp change between the developers without the noticing AND
        # - you ignore the server fingerprint checks
        # You have been helped and you have been warned.
        #
        # Example:
        #"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICwsW+YJw6ukhoWPEBLN93EFiGhN7H2VJn5yZcKId56W mb@mmm"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5gQR9UyrTfQBZew9l3uHR6LghMY+BSlvBytHFMjJvvrSlBWO7dYFUuaRY15BnDDn3HQKVRKAWV9iEbNH/TttcJQ4FqEcXYtKpLqFzFQDb3mK3nABY0h1fJKT71MfDfdbPrZzFuZT6bm1pU8fSOPgkUzVggfMYIIe3dtsrGVh06rbKGlYWdJKmKgmzyoDYOHvRee/ez7RY2cp4dMjHu5kmOP6WMbr9Zl4xiF0OFs2WI/dMQJmi8uYoQmR+UbPJeKSJY1Hq4vJTqijGsAwkUHl+p9JBsfOsrvy2mAjRtUR+Vb+qaMd1AW6wuByOT8vfRsHUZvX1O3jkVfY7/rz0O2u7 toros.gokkurt@tii.ae"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXCdSgQtSvxRpQoQZt+AkDichPaRG/GaWZwAMgKwT3y ilkka.siiki@solita.fi"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9Y06NJE/jcPcz7uSE0fwavqzW5jrOb6Pyp1ZZ+pDjp janne.sangi@tii.ae"
      ];
    };
  };

  config = mkIf cfg.enable {
    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedSshKeys;
    users.users.${config.ghaf.users.admin.name}.openssh.authorizedKeys.keys = cfg.authorizedSshKeys;
  };
}
