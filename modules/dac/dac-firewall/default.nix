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
      ip,
      action,
      state,
      kmsip,
      gwip,
    }:
    ''
    /run/current-system/sw/bin/ip ad ${action} ${ip} dev "$IFACE" 2> /dev/null || true
    logger -t fmo-fw "${action} IP ${ip} to $IFACE"

    /run/current-system/sw/bin/ip link set dev "$IFACE" ${state} 2> /dev/null || true
    logger -t fmo-fw "$IFACE set to ${state}"

    /run/current-system/sw/bin/ip route ${action} ${kmsip} via ${gwip} dev "$IFACE" 2> /dev/null || true
    logger -t fmo-fw "${action}: $IFACE -> ${kmsip} via ${gwip}"
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
      type = types.attrs;
      description = ''
        {
            ip = interface IP address,
            kmsip = KMS IP address,
            gwip = gateway IP address,
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
    environment.etc."NetworkManager/dispatcher.d/99-fmo-kms" = {
      text = ''
        #!/bin/sh

        add_rules(){
            ${mkFirewallRules {
                    inherit (cfg.configuration) ip;
                    action = "add";
                    state = "up";
                    inherit (cfg.configuration) kmsip;
                    inherit (cfg.configuration) gwip;
                }
            }
        }

        remove_rules(){
            ${mkFirewallRules {
                    inherit (cfg.configuration) ip;
                    action = "add";
                    state = "up";
                    inherit (cfg.configuration) kmsip;
                    inherit (cfg.configuration) gwip;
                }
            }
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
                    add_rules

                    # Set MTU for the interface
                    ${optionalString (cfg.mtu != null) ''ip link set dev "$iface" mtu ${toString cfg.mtu}''}
                else
                    log "Interface $iface is down, removing rules"
                    remove_rules
                fi
            fi
        done
      '';
      mode = "0700";
    };

  };
}
