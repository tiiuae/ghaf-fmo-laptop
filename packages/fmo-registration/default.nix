# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  registration-agent,
  ipcalc,
  gawk,
  grpcurl,
}:
writeShellApplication {
  name = "fmo-registration";

  runtimeInputs = [
    gawk
    registration-agent
    ipcalc
    grpcurl
  ];

  text =
    # FIXME Read hostname and IP from user. This is a temporary solution and
    # should be replaced with a proper setup.
    #
    # Host and IP file paths are hardcoded in registration agent. We share these
    # with internal storage until better solution is implemented.
    ''
      set +euo pipefail
      echo -e "\e[1;32;1mFMO Registration \e[0m"

      IP_FILE=/var/common/ip-address
      HOSTNAME_FILE=/var/common/hostname

      set_hostname(){
        # Read hostname from user
        read -e -r -p "Enter mDNS hostname: " HOSTNAME
        HOSTNAME=''${HOSTNAME// /_}
        HOSTNAME=''${HOSTNAME//[^a-zA-Z0-9_-]/}
        HOSTNAME=''$(echo -n "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
        echo "$HOSTNAME" > $HOSTNAME_FILE
        # Start msg-vm service to process the new hostname
        # grpcurl -cacert /etc/givc/ca-cert.pem -cert /etc/givc/cert.pem -key /etc/givc/key.pem -d '{"UnitName": "fmo-update-hostname.service"}' msg-vm:9000 systemd.UnitControlService.StartUnit > /dev/null 2>&1
        echo "Hostname set to $HOSTNAME"
      }

      set_ip(){
        # Read IP from user
        VALID_IP=false
        until $VALID_IP; do
          read -e -r -p "Enter fixed external IP: " IP
          if ipcalc -c "$IP"; then
            echo "$IP" > $IP_FILE
            echo "IP set to $IP"
            # Start net-vm service to process the new IP
            grpcurl -cacert /etc/givc/ca-cert.pem -cert /etc/givc/cert.pem -key /etc/givc/key.pem -d '{"UnitName": "fmo-update-ipaddress.service"}' net-vm:9000 systemd.UnitControlService.StartUnit > /dev/null 2>&1
            echo "Please wait for the NetworkManager to restart..."
            VALID_IP=true
          else
            echo "Invalid IP address: $IP"
          fi
        done
      }

      # Set mDNS hostname
      echo ""
      [[ ! -f $HOSTNAME_FILE ]] && touch $HOSTNAME_FILE
      HOSTNAME=$(gawk '{print $1}' $HOSTNAME_FILE)
      if [ -n "$HOSTNAME" ]; then
        echo "Current mDNS hostname: $HOSTNAME"
        read -r -p 'Do you want to update the hostname? [y/N] ' response
        case "$response" in
        [yY][eE][sS] | [yY])
          set_hostname
          ;;
        *)
          echo "Skipping hostname update..."
          ;;
        esac
      else
        echo "No mDNS hostname is set."
        set_hostname
      fi

      # Set fixed IP address
      echo ""
      [[ ! -f $IP_FILE ]] && touch $IP_FILE
      IP=$(gawk '{print $1}' $IP_FILE)
      if [ -n "$IP" ]; then
        echo "Current IP address: $IP"
        read -r -p 'Do you want to update the IP address? [y/N] ' response
        case "$response" in
        [yY][eE][sS] | [yY])
          set_ip
          ;;
        *)
          echo "Skipping IP address update..."
          ;;
        esac
      else
        echo "No IP address is set."
        set_ip
      fi

      echo ""
      read -r -p 'Do you want to start the registration agent? [y/N] ' response
      case "$response" in
      [yY][eE][sS] | [yY])
        cat $IP_FILE > /var/lib/fogdata/ip-address
        cat $HOSTNAME_FILE > /var/lib/fogdata/hostname
        /run/current-system/sw/bin/registration-agent-laptop
      ;;
      *)
      ;;
      esac

      echo "Exiting..."

      # Wait to allow user to read output
      sleep 2
    '';

  meta = {
    description = "Wrapper script for registration agent.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
