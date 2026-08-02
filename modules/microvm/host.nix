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
        # ca-path holds ca.key and stays host-only; only ca-public-path, which
        # contains ca.crt alone, is shared into the VMs.
        ca-path = "/run/certs/nats/ca";
        ca-public-path = "/run/certs/nats/ca-pub";
        # No server certificate: the only thing that served TLS from this host
        # was the msg-VM's NATS server, removed in 82ba0dc. The operational
        # NATS the containers talk to runs in the docker-VM and brings its own.
        clients-paths = [
          "/run/certs/nats/clients/host"
          "/run/certs/nats/clients/netvm"
          "/run/certs/nats/clients/dockervm"
        ];
      };
    };

    # Create MicroVM host share folders
    systemd.tmpfiles.rules = [
      # 0755, matching ghaf, and NOT the 0700 this used to be. 0700 broke SPIRE
      # on every VM:
      "z /persist/common 0755 root root -"
      "d /persist/fogdata 0700 ${toString config.ghaf.users.homedUser.uid} users -"
      "f /persist/common/hostname 0600 root root -"
      "f /persist/common/ip-address 0600 root root -"
    ];

    ghaf.virtualization.microvm.guivm.applications = [
      {
        name = "google-chrome-gpu";
        desktopName = "Google Chrome GPU";
        description = "Google Chrome with GPU acceleration";
        icon = "thorium-browser";
        exec = "/run/current-system/sw/bin/google-chrome-stable";
      }
      {
        name = "firefox-gpu";
        desktopName = "Firefox GPU";
        description = "Firefox Beta with GPU acceleration";
        icon = "firefox";
        exec = "/run/current-system/sw/bin/firefox";
      }
      {
        name = "display-settings";
        desktopName = "Display Settings";
        description = "Manage displays and resolutions";
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/devices/display.svg";
        exec = "${pkgs.wdisplays}/bin/wdisplays";
      }
    ];
  };
}
