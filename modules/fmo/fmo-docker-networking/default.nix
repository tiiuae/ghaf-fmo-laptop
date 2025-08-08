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
    mkForce
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

    ghaf.firewall = rec {
      allowedTCPPorts = [
        80
        123
        4222
        4223
        4280
        4290
        5432
        6422
        7222
        8888
        9876
      ];
      allowedUDPPorts = [
        123
        4222
        6423
        7222
      ];
      extra = {
        forward.filter =
          map (port: "-i ethint0 -o 'br-+' -p tcp --dport ${toString port} -j ACCEPT") allowedTCPPorts
          ++ map (port: "-i ethint0 -o 'br-+' -p udp --dport ${toString port} -j ACCEPT") allowedUDPPorts;
      };
    };
    # NAT translation for docker bridge network
    # used by operational-nats
    networking.nat = {
      enable = mkForce true;
      externalInterface = "ethint0";
      inherit (cfg) internalIPs;
    };

    # TODO Write static IP range for docker bridge to file
    # to be picked up by docker daemon for configuration.
    # environment.etc."docker.json".text = ''
    # '';

  };
}
