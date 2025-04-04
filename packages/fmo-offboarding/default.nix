# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  docker,
}:
writeShellApplication {
  name = "fmo-offboarding";
  runtimeInputs = [ docker ];
  text = ''
    echo -e "\e[1;32;1mFMO Offboarding \e[0m"
    echo ""

    read -r -p 'Do you want to de-register the device and remove all FMO data? [y/N] ' response
    case "$response" in
    [yY][eE][sS] | [yY])

      # Stop docker
      echo -n "Stopping docker..."
      systemctl stop docker.socket docker.service
      echo " done."

      # Remove data
      echo -n "Removing FMO data..."
      rm -rf /var/lib/fogdata/*
      rm -rf /var/common/*
      rm -rf /var/lib/internal/*
      rm -rf /var/lib/docker/*
      echo " done."

      echo "Offboarding completed. Please reboot the system to apply changes."
      sleep 3

      # TODO Uncomment this if you want to enable
      # reprovisioning without reboot. You may run
      # into problems if you changed the system
      # configuration witout rebooting.

      # # Restart setup-onboarding-agent
      # systemctl restart setup-onboarding-agent.service

      # echo -n "Restarting docker..."
      # systemctl start docker.socket docker.service
      # echo " done."
      ;;
    *)
      echo "Skipping offboarding..."
      sleep 3
      ;;
    esac
  '';

  meta = {
    description = "Script to remove all FMO registration data and content.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
