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
      action,
    }:
    ''
      /run/current-system/sw/sbin/iptables -t nat -${action} ghaf-fw-pre-nat -i "$IFACE" -p ${proto} --dport ${sport} -j DNAT --to-destination ${dip}:${dport} 2> /dev/null || true
      /run/current-system/sw/sbin/iptables -t filter -${action} ghaf-fw-fwd-filter -i "$IFACE" -p ${proto} --dport ${sport} -j ACCEPT 2> /dev/null || true
      /run/current-system/sw/sbin/iptables -t nat -${action} ghaf-fw-post-nat -o "$IFACE" -p ${proto} --dport ${sport} -j MASQUERADE 2> /dev/null || true
      logger -t fmo-fw "${action} rule on $IFACE: ${proto} ${sport} -> ${dip}:${dport}"
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

    ghaf.firewall = {
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
              action = "A";
            }
          ) cfg.configuration}
        }

        remove_rules() {
          ${concatMapStringsSep "\n" (
            rule:
            mkFirewallRules {
              inherit (rule) dip;
              inherit (rule) sport;
              inherit (rule) dport;
              inherit (rule) proto;
              action = "D";
            }
          ) cfg.configuration}
        }

        # Exclude loopback interface
        if [ "$IFACE" == "lo" ] || echo "$IFACE" | grep -q "^vlan"; then
          exit 0
        fi

        case "$STATUS" in
          up)
            log "Interface $IFACE is up, applying rules"
            # Add port forwarding rules
            add_rules

            # Set MTU for the interface
            ${optionalString (cfg.mtu != null) ''ip link set dev "$IFACE" mtu ${toString cfg.mtu}''}
          ;;
          down)
              log "Interface $IFACE is down, removing rules"
              remove_rules
          ;;
        esac
      '';
      mode = "0700";
    };

  };
}
