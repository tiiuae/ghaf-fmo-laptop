# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.dac-usb-network-configuration;

  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  mkFirewallRules =
    {
      ip,
      action,
      state,
      kmsip,
      gwip,
    }:
    ''
      ${pkgs.iproute2}/bin/ip ad ${action} ${ip} dev "$IFACE" 2> /dev/null || true
      logger -t dac-usb-network-configuration "${action} IP ${ip} to $IFACE"

      ${pkgs.iproute2}/bin/ip link set dev "$IFACE" ${state} 2> /dev/null || true
      logger -t dac-usb-network-configuration "$IFACE set to ${state}"

      ${pkgs.iproute2}/bin/ip route ${action} ${kmsip} via ${gwip} dev "$IFACE" 2> /dev/null || true
      logger -t dac-usb-network-configuration "${action}: $IFACE -> ${kmsip} via ${gwip}"
    '';
in
{
  options.services.dac-usb-network-configuration = {
    enable = mkEnableOption "dac-usb-network-configuration";

    ip = mkOption {
      type = types.str;
      description = ''
        IP address to be assigned to the external network interfaces.
      '';
      default = "192.168.101.200/24";
    };

    kmsip = mkOption {
      type = types.str;
      description = ''
        KMS server IP address.
      '';
      default = "100.66.96.2/32";
    };

    gwip = mkOption {
      type = types.str;
      description = ''
        Gateway IP address for the external network interfaces.
      '';
      default = "192.168.101.254";
    };
  };

  config = mkIf cfg.enable {

    # Set network for USB ethernet adapters
    environment.etc."NetworkManager/dispatcher.d/99-dac-usb-network-configuration" = {
      text = ''
                #!/bin/sh
                IFACE="$1"
                STATUS="$2"

        	      logger -t dac-usb-network-configuration "Dispatcher triggered: IFACE=$IFACE STATUS=$STATUS"

                add_rules(){
                    ${mkFirewallRules {
                      inherit (cfg) ip;
                      action = "add";
                      state = "up";
                      inherit (cfg) kmsip;
                      inherit (cfg) gwip;
                    }}
                }

                remove_rules(){
                    ${mkFirewallRules {
                      inherit (cfg) ip;
                      action = "del";
                      state = "down";
                      inherit (cfg) kmsip;
                      inherit (cfg) gwip;
                    }}
                }
        	
                # Skip loopback and common virtual interfaces
                [[ "$IFACE" == "lo" ]] && exit
                [[ "$IFACE" =~ tun|vbox|docker|veth|br-|virbr ]] && exit

                # Only Ethernet type (1)
                type=$(cat /sys/class/net/$IFACE/type)
                [[ "$type" != "1" ]] && exit            

                # Check if backed by USB
                if readlink -f /sys/class/net/$IFACE | grep -q '/usb'; then
                    logger -t dac-usb-network-configuration "$IFACE is a USB Ethernet adapter"

                    if [ "$STATUS" = "up" ]; then
                        logger -t dac-usb-network-configuration "Interface $IFACE is up, applying rules"
                        add_rules
                    else
                        logger -t dac-usb-network-configuration "Interface $IFACE is down, removing rules"
                        remove_rules
                    fi
                fi
      '';
      mode = "0700";
    };

  };
}
