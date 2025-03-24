# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.fmo-firewall;

  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    concatMapStringsSep
    types
    ;

  mkFirewallRules =
    {
      interface,
      dip,
      sport,
      dport,
      proto,
    }:
    ''
      iptables -t nat -A PREROUTING -i ${interface} -p ${proto} --dport ${sport} -j DNAT --to-destination ${dip}:${dport}
      iptables -t nat -A POSTROUTING -o ${interface} -p ${proto} --dport ${sport} -j MASQUERADE
    '';

in
{
  options.services.fmo-firewall = {
    enable = mkEnableOption "fmo-firewall";

    externalNics = mkOption {
      type = types.listOf types.str;
      description = ''
        List of external network interfaces that
      '';
    };

    configuration = mkOption {
      type = types.listOf types.attrs;
      description = ''
        List of
          {
            dip = destanation IP address,
            sport = source port,
            dport = destanation port,
            proto = protocol (udp, tcp)
          }
      '';
    };
  };

  config = mkIf cfg.enable {

    networking.firewall = {
      enable = true;
      extraCommands = ''
        ${concatMapStringsSep "\n" (
          rule:
          (concatMapStringsSep "\n" (
            nic:
            mkFirewallRules {
              interface = nic;
              inherit (rule) dip;
              inherit (rule) sport;
              inherit (rule) dport;
              inherit (rule) proto;
            }
          ) cfg.externalNics)
        ) cfg.configuration}
      '';
    };

  };
}
