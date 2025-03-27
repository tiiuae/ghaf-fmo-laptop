# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.fmo-docker-networking;

  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

in
{
  options.services.fmo-docker-networking = {
    enable = mkEnableOption "FMO docker networking configuration";

    internalIPs = mkOption {
      type = types.listOf types.str;
      description = ''
        List of docker network ranges for NAT translation.
      '';
      default = [ "172.18.0.0/16" ];
    };

  };

  config = mkIf cfg.enable {

    # TODO Enable firewall and test
    networking.firewall.enable = false;

    # TODO inherit firewall ports from fmo-firewall in docker
    # networking.firewall.allowedTCPPorts = [
    #   123
    #   6422
    #   6423
    #   4222
    #   7222
    # ];
    # networking.firewall.allowedUDPPorts = [
    #   123
    #   6422
    #   6423
    #   4222
    #   7222
    # ];

    # NAT translation for docker bridge network
    # used by operational-nats
    networking.nat = {
      enable = true;
      externalInterface = "ethint0";
      inherit (cfg) internalIPs;
    };

    # TODO Write static IP range for docker bridge to file
    # to be picked up by docker daemon for configuration.
    # environment.etc."docker.json".text = ''
    # '';

  };
}
