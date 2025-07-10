# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  ipcalc,
  gawk,
  grpcurl,
  fzf,
  networkmanager,
}:
writeShellApplication {
  name = "fmo-set-netw-con";

  bashOptions = [ ];

  runtimeInputs = [
    gawk
    ipcalc
    grpcurl
    fzf
    networkmanager
  ];

  text = ''
    set +euo pipefail
    echo -e "\e[1;32;1mFMO set networking \e[0m"

    set_network_con() {
        CON_IP=""
        GW_IP=""
        NETMASK=""
        echo "Select network interface:"
        NCON=$(nmcli con show |cut -d" "  -f1|fzf --layout=reverse)
        echo -e "\nSelected network: $NCON"

        # Read IP from user
        VALID_IP=false
        until $VALID_IP; do
            read -e -r -p "Enter IP Address: " IP
            if ipcalc -c "$IP"; then
                VALID_IP=true
                CON_IP=$IP
            else
                echo "Invalid IP address: $IP"
            fi
        done

        # Read NETMASK prefix from user
        VALID_NETM=false
        until $VALID_NETM; do
          read -e -r -p "Enter Netmask prefix: " NETM
          # Make sure it's a number between 0 and 32
          if [[ "$NETM" =~ ^[0-9]+$ ]] && (( NETM >= 0 && NETM <= 32 )); then
              VALID_NETM=true
              NETMASK=$NETM
          else
              echo "$NETM is NOT valid: 0-32 allowed."
          fi
        done

        # Read Gateway IP from user
        VALID_IP=false
        until $VALID_IP; do
            read -e -r -p "Enter Gateway IP Address: " IP
            if ipcalc -c "$IP"; then
                VALID_IP=true
                GW_IP=$IP 
            else
                echo "Invalid Gateway IP address: $IP"
            fi
        done

        echo -e "\n"
        #echo "IP Address: $CON_IP"
        #echo "Gateway IP Address: $GW_IP"
        nmcli con mod "$NCON" ipv4.addresses "$CON_IP"/"$NETMASK" \
            ipv4.gateway "$GW_IP" \
            ipv4.dns 8.8.8.8 \
            ipv4.method manual

        echo "Deactivate $NCON"
        nmcli con down "$NCON"
        sleep 1
        echo "Activate $NCON"
        nmcli con up "$NCON"
    }

    # Choose some active connection
    read -r -p 'Do you want to set the network connection now? [y/N] ' response
    case "$response" in
    [yY][eE][sS] | [yY])
        set_network_con
        ;;
    *)
        ;;
    esac

    # Wait to allow user to read output
    while true; do
      read -r -p 'Press [Enter] to exit...'
      break
    done
  '';

  meta = {
    description = "Script for setting connection to a mesh network.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
