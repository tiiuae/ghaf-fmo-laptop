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
    types
    optionalString
    concatMapStringsSep
    ;

  mkFirewallRules =
    {
      dip,
      sport,
      dport,
      proto,
    }:
    ''
      /run/current-system/sw/sbin/iptables -t nat -A PREROUTING -i "$IFACE" -p ${proto} --dport ${sport} -j DNAT --to-destination ${dip}:${dport}
      /run/current-system/sw/sbin/iptables -t nat -A POSTROUTING -o "$IFACE" -p ${proto} --dport ${sport} -j MASQUERADE
    '';

in
{
  options.services.fmo-firewall = {
    enable = mkEnableOption "fmo-firewall";

    mtu = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        MTU for the external network interfaces.
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
    };

    # Set MTU for external USB network devices
    services.udev.extraRules = optionalString (cfg.mtu != null) ''
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="usb*", ATTR{mtu}="${toString cfg.mtu}"
    '';

    # Set MTU and port forwarding rules for external network interfaces
    environment.etc."NetworkManager/dispatcher.d/99-fmo-rules" = {
      text = ''
        #!/bin/sh
        IFACE="$1"
        STATUS="$2"

        add_rules(){
          ${concatMapStringsSep "\n" (
            rule:
            mkFirewallRules {
              inherit (rule) dip;
              inherit (rule) sport;
              inherit (rule) dport;
              inherit (rule) proto;
            }
          ) cfg.configuration}
        }

        # Exclude loopback interface
        if [ "$IFACE" == "lo" ]; then
          exit 0
        fi

        case "$STATUS" in
          up)
            # Add port forwarding rules
            add_rules

            # Set MTU for the interface
            ${optionalString (cfg.mtu != null) ''ip link set dev "$IFACE" mtu ${toString cfg.mtu}''}
          ;;
        esac
      '';
      mode = "0700";
    };

  };
}
