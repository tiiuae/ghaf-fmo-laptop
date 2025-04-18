# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) hasAttr optionals;
  inherit (config.ghaf.networking) hosts;
  isMsgvmEnabled = hasAttr "msg-vm" config.microvm.vms;
in
{
  config = {

    # TODO FMO_BUILD_VERSION
    # TODO RAV version, we will not support the hyperconfig
    # fmo-system = {
    #   RAversion = "v0.8.4";
    # };

    environment.systemPackages = [
      pkgs.vim
      pkgs.tcpdump
      pkgs.gpsd
      pkgs.natscli
    ];

    services = {

      # TODO check if this is required and its dependencies (fmo-config.yaml?)
      # environment.systemPackages = [ pkgs.fmo-tool ];

      fmo-certs-distribution-service-host = {
        enable = true;
        ca-name = "NATS CA";
        ca-path = "/run/certs/nats/ca";
        server-ips = [
          "127.0.0.1"
        ] ++ optionals isMsgvmEnabled "${hosts.msg-vm.ipv4}";
        server-name = "NATS-server";
        server-path = "/run/certs/nats/server";
        clients-paths = [
          "/run/certs/nats/clients/host"
          "/run/certs/nats/clients/netvm"
          "/run/certs/nats/clients/dockervm"
        ];
      }; # services.fmo-certs-distribution-service-host
    };

    # Create MicroVM host share folders
    systemd.tmpfiles.rules = [
      "d /persist/common 0700 root root -"
      "d /persist/fogdata 0700 ${toString config.ghaf.users.loginUser.uid} users -"
      # TODO is this actually meant to be temporary?
      "d /persist/tmp 0700 microvm kvm -"
      # TODO remove this when better hostname/ip setting option is implemented
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
