# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.dac-firewall;

  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    optionalString
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
      /run/current-system/sw/bin/ip ad ${action} ${ip} dev "$1" 2> /dev/null || true
      logger -t fmo-fw "${action} IP ${ip} to $1"

      /run/current-system/sw/bin/ip link set dev "$1" ${state} 2> /dev/null || true
      logger -t fmo-fw "$1 set to ${state}"

      /run/current-system/sw/bin/ip route ${action} ${kmsip} via ${gwip} dev "$1" 2> /dev/null || true
      logger -t fmo-fw "${action}: $1 -> ${kmsip} via ${gwip}"
    '';
in
{
  options.services.dac-firewall = {
    enable = mkEnableOption "dac-firewall";

    mtu = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        MTU for the external network interfaces.
      '';
    };

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

    ghaf.firewall = {
      enable = true;
    };

    # Set MTU for external USB network devices
    services.udev.extraRules = optionalString (cfg.mtu != null) ''
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="usb*", ATTR{mtu}="${toString cfg.mtu}"
    '';

    # Set MTU and port forwarding rules for external network interfaces
    environment.etc."NetworkManager/dispatcher.d/99-fmo-kms" = {
      text = ''
        #!/bin/sh

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
              action = "add";
              state = "up";
              inherit (cfg) kmsip;
              inherit (cfg) gwip;
            }}
        }

        echo "Detecting USB Ethernet adapters..."

        for iface in /sys/class/net/*; do
            iface=$(basename "$iface")
            
            # Skip loopback and common virtual interfaces
            [[ "$iface" == "lo" ]] && continue
            [[ "$iface" =~ tun|vbox|docker|veth|br-|virbr ]] && continue

            # Only Ethernet type (1)
            type=$(cat /sys/class/net/$iface/type)
            [[ "$type" != "1" ]] && continue

            # Check if backed by USB
            if readlink -f /sys/class/net/$iface | grep -q '/usb'; then
                log "$iface is a USB Ethernet adapter"

                # TODO: Set rule if status is UP, remove if DOWN
                status=$(cat /sys/class/net/$iface/operstate)
                if [ "$status" = "up" ]; then
                    log "Interface $iface is up, applying rules"
                    add_rules "$iface"

                    # Set MTU for the interface
                    ${optionalString (cfg.mtu != null) ''ip link set dev "$iface" mtu ${toString cfg.mtu}''}
                else
                    log "Interface $iface is down, removing rules"
                    remove_rules "$iface"
                fi
            fi
        done
      '';
      mode = "0700";
    };

  };
}
