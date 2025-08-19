# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  config,
  pkgs,
  ...
}:
let

  appuser = config.ghaf.users.appUser.name;
in
{
  # TODO implement appvm interface and remove these imports
  imports = [
    ../../fmo/fmo-dci-service
    ../../fmo/fmo-dci-passthrough
    ../../fmo/fmo-onboarding-agent
    ../../fmo/fmo-update-hostname
    ../../fmo/fmo-docker-networking
    ../../dac/dac-agent
    ../../dac/dac-nats-server
  ];

  config = {
    # Packages
    environment.systemPackages = [
      pkgs.vim
      pkgs.tcpdump
      pkgs.gpsd
      pkgs.natscli
      pkgs.device-assembly-agent
      pkgs.nats-server
    ];

    # Use givc service & app manager
    # TODO This is currently not supported in givc as it has a microvm dependency

    # MTU
    systemd.network.links."10-ethint0".extraConfig = "MTUBytes=1372";

    # MicroVM
    microvm = {
      # TODO Should we use storagevm instead?
      volumes = [
        {
          image = "/persist/tmp/dockervm_internal.img";
          mountPoint = "/var/lib/internal";
          size = 10240;
          autoCreate = true;
          fsType = "ext4";
        }
        {
          image = "/persist/tmp/dockervm.img";
          mountPoint = "/var/lib/docker";
          size = 51200;
          autoCreate = true;
          fsType = "ext4";
        }
      ]; # microvm.volumes

      shares = [
        {
          source = "/persist/common";
          mountPoint = "/var/common";
          tag = "common_share_dockervm";
          proto = "virtiofs";
          socket = "common_share_dockervm.sock";
        }
        {
          source = "/persist/fogdata";
          mountPoint = "/var/lib/fogdata";
          tag = "fogdatafs";
          proto = "virtiofs";
          socket = "fogdata.sock";
        }
        {
          source = "/run/certs/nats/clients/dockervm";
          mountPoint = "/var/lib/nats/certs";
          tag = "nats_dockervm_certs";
          proto = "virtiofs";
          socket = "nats_dockervm_certs.sock";
        }
        {
          source = "/run/certs/nats/ca";
          mountPoint = "/var/lib/nats/ca";
          tag = "nats_dockervm_ca_certs";
          proto = "virtiofs";
          socket = "nats_dockervm_ca_certs.sock";
        }
      ]; # microvm.shares
    }; # microvm

    # Terminal and fonts
    fonts.packages = [ pkgs.nerd-fonts.fira-code ];
    programs.foot = {
      enable = true;
      settings.main.font = "FiraCode Nerd Font Mono:size=10";
    };

    # Allow app user in this vm to run root commands for on-/offboarding and DAC agent
    security.sudo.extraConfig = ''
      ${appuser} ALL=(root) NOPASSWD: ${pkgs.fmo-onboarding}/bin/fmo-onboarding
      ${appuser} ALL=(root) NOPASSWD: ${pkgs.fmo-offboarding}/bin/fmo-offboarding
      ${appuser} ALL=(root) NOPASSWD: ${pkgs.device-assembly-agent}/bin/device-assembly-agent
    '';

    users.groups."plugdev" = { };

    # Udev rules for Yubikey
    services.udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0407", TAG+="uaccess", GROUP="kvm", MODE="0666"
    '';

    # Services
    services = {

      # TODO enable monitoring service
      # fmo-monitor-service = {
      #   enable = true;
      #   nats-ip = "192.168.101.111";
      #   ca-crt-path = "/var/lib/nats/ca/ca.crt";
      #   client-key-path = "/var/lib/nats/certs/client.key";
      #   client-crt-path = "/var/lib/nats/certs/client.crt";
      #   services = [ "fmo-dci.service" ];
      #   topics = [ "dockervm/logs/fmo-dci" ];
      # };

      fmo-docker-networking = {
        enable = true;
      };

      fmo-dci-passthrough = {
        enable = true;
        container-name = "swarm-server-pmc01-swarm-server-1";
        vendor-id = "1050";
      };

      fmo-dci = {
        enable = true;
        compose-path = "/var/lib/fogdata/docker-compose.yml";
        update-path = "/var/lib/fogdata/docker-compose.yml.new";
        backup-path = "/var/lib/fogdata/docker-compose.yml.backup";
        pat-path = "/var/lib/fogdata/PAT.pat";
        preloaded-images = "tii-offline-map-data-loader.tar.gz";
        # docker-url = "cr.airoplatform.com";
        docker-url = "ghcr.io";
        docker-url-path = "/var/lib/fogdata/cr.url";
        docker-mtu = 1372;
      };

      avahi = {
        enable = true;
        nssmdns4 = true;
      };

      fmo-update-hostname = {
        enable = true;
        hostnamePath = "/var/common/hostname";
      };

      # Setup service for onboarding agent
      fmo-onboarding-agent = {
        enable = true;
        certs_path = "/var/lib/fogdata/certs";
        config_path = "/var/lib/fogdata";
        token_path = "/var/lib/fogdata";
        hostname_path = "/var/lib/fogdata";
        ip_path = "/var/lib/fogdata";
        post_install_path = "/var/lib/fogdata/certs";
        enable_dac = true;
        dac_file_path = "/var/lib/fogdata/dac/dac.json";
      };

      dac-nats-server = {
        enable = true;
      };

      dac-agent = {
        enable = true;
      };
    }; # services
  }; # config
}
