# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  ...
}:
{
  config = {
    environment.systemPackages = [
      pkgs.vim
      pkgs.tcpdump
      pkgs.gpsd
      pkgs.natscli
    ];

    services = {
      fmo-certs-distribution-service-host = {
        enable = true;
        ca-name = "NATS CA";
        ca-path = "/run/certs/nats/ca";
        server-ips = [ "127.0.0.1" ];
        server-name = "NATS-server";
        server-path = "/run/certs/nats/server";
        clients-paths = [
          "/run/certs/nats/clients/host"
          "/run/certs/nats/clients/netvm"
          "/run/certs/nats/clients/dockervm"
        ];
      };
    };

    # Create MicroVM host share folders
    systemd.tmpfiles.rules = [
      "d /persist/common 0700 root root -"
      "d /persist/fogdata 0700 ${toString config.ghaf.users.homedUser.uid} users -"
      "f /persist/common/hostname 0600 root root -"
      "f /persist/common/ip-address 0600 root root -"
    ];

    ghaf.virtualization.microvm.guivm.applications = [
      {
        name = "Google Chrome GPU";
        description = "Google Chrome with GPU acceleration";
        icon = "thorium-browser";
        command = "/run/current-system/sw/bin/google-chrome-stable";
      }
      {
        name = "Firefox GPU";
        description = "Firefox Beta with GPU acceleration";
        icon = "firefox";
        command = "/run/current-system/sw/bin/firefox";
      }
      {
        name = "Display Settings";
        description = "Manage displays and resolutions";
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/devices/display.svg";
        command = "${pkgs.wdisplays}/bin/wdisplays";
      }
    ];
  };
}
