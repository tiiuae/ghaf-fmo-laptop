# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  onboarding-agent,
  ipcalc,
  gawk,
  grpcurl,
}:
writeShellApplication {
  name = "fmo-onboarding";

  runtimeInputs = [
    gawk
    onboarding-agent
    ipcalc
    grpcurl
  ];

  text =
    # FIXME Read hostname and IP from user. This is a temporary solution and
    # should be replaced with a proper setup.
    #
    # Host and IP file paths are hardcoded in onboarding agent. We share these
    # with internal storage until better solution is implemented.
    ''
      set +euo pipefail
      echo -e "\e[1;32;1mFMO Onboarding \e[0m"

      IP_FILE=/var/common/ip-address
      HOSTNAME_FILE=/var/common/hostname
      CONFIG_FILE=/var/lib/fogdata/config.yaml

      set_hostname(){
        VALID_HOSTNAME=false
        until $VALID_HOSTNAME; do
          # Read hostname from user
          read -e -r -p "Enter mDNS hostname: " HOSTNAME
          if [[ -z "$HOSTNAME" ]]; then
            echo "Hostname cannot be empty."
            continue
          fi
          HOSTNAME=''${HOSTNAME// /_}
          HOSTNAME=''${HOSTNAME//[^a-zA-Z0-9_-]/}
          HOSTNAME=''$(echo -n "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
          echo -n "$HOSTNAME" > $HOSTNAME_FILE
          VALID_HOSTNAME=true
          echo "Hostname set to $HOSTNAME"
        done
      }

      set_ip(){
        # Read IP from user
        VALID_IP=false
        until $VALID_IP; do
          read -e -r -p "Enter fixed external IP: " IP
          if ipcalc -c "$IP"; then
            echo -n "$IP" > $IP_FILE
            echo "IP set to $IP"
            VALID_IP=true
          else
            echo "Invalid IP address: $IP"
          fi
        done
      }

      set_alias() {
        # Read alias from user
        read -r -p "Enter the alias for the device: " alias

        # Update the alias in the config file
        sed -i -e "s/Alias: .*/Alias: \"$alias\"/" "$CONFIG_FILE"
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

      # Set device alias
      echo ""
      read -r -p "Do you want to set an alias for this device [y/N]? " response
      case "$response" in
      [yY][eE][sS] | [yY])
        set_alias
        ;;
      *)
        echo "No alias set."
        ;;
      esac

      echo ""
      read -r -p 'Do you want to start the onboarding agent? [y/N] ' response
      case "$response" in
      [yY][eE][sS] | [yY])
        cat $IP_FILE > /var/lib/fogdata/ip-address
        cat $HOSTNAME_FILE > /var/lib/fogdata/hostname
        /run/current-system/sw/bin/onboarding-agent  --config $CONFIG_FILE --log-file /var/lib/fogdata/onboarding-agent.log --encrypt-secrets
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
    description = "Wrapper script for onboarding agent.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
