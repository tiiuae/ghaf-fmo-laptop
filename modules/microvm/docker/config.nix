# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  ...
}:
let
  appuser = config.ghaf.users.appUser.name;
in
{
  config = {
    environment.systemPackages = [
      pkgs.vim
      pkgs.tcpdump
      pkgs.gpsd
      pkgs.natscli
    ];

    systemd.network.links."10-ethint0".extraConfig = "MTUBytes=1372";

    ghaf.storagevm = {
      maximumSize = 62 * 1024;

      # ghaf defaults to [ "rw" "nodev" "nosuid" "noexec" ]. noexec and nodev are
      # omitted here because Docker needs exec to launch runc and dev for the
      # overlay2 storage driver.
      #
      # NOTE: mountOptions applies to the whole /guestStorage volume, not just
      # /var/lib/docker, so every preserved path in this VM - /var/lib/nixos,
      # /var/lib/internal, /home/appuser, the journal - is exec and dev capable
      # too. Also note this drops suid relative to the dedicated microvm.volumes
      # this replaced, which inherited the "defaults" mount options.
      mountOptions = [
        "rw"
        "nosuid"
      ];
      directories = [
        {
          directory = "/var/lib/internal";
          user = "root";
          group = "root";
          mode = "0755";
        }
        {
          directory = "/var/lib/docker";
          user = "root";
          group = "root";
          mode = "0710";
        }
      ];
    };

    microvm = {
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
          source = "/run/certs/nats/ca-pub";
          mountPoint = "/var/lib/nats/ca";
          tag = "nats_dockervm_ca_certs";
          proto = "virtiofs";
          socket = "nats_dockervm_ca_certs.sock";
        }
      ];
    };

    fonts.packages = [ pkgs.nerd-fonts.fira-code ];
    programs.foot = {
      enable = true;
      settings.main.font = "FiraCode Nerd Font Mono:size=10";
    };

    security.sudo.extraConfig = ''
      ${appuser} ALL=(root) NOPASSWD: ${pkgs.fmo-onboarding}/bin/fmo-onboarding
      ${appuser} ALL=(root) NOPASSWD: ${pkgs.fmo-offboarding}/bin/fmo-offboarding
    '';

    users.groups."plugdev" = { };

    # Udev rule for YubiKey-based hardware authentication (e.g., SSH keys)
    services.udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0407", TAG+="uaccess", GROUP="kvm", MODE="0666"
    '';

    services = {
      fmo-docker-networking.enable = true;

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
        docker-url = "ghcr.io";
        docker-url-path = "/var/lib/fogdata/cr.url";
        docker-mtu = 1372;
      };

      avahi = {
        enable = true;
        nssmdns4 = true;
      };

      fmo-update-hostname = {
        # Kernel hostname only. The avahi half stays off here: this VM's
        # avahi has publish.enable = false (the default), so renaming its
        # daemon announced nothing. Publishing happens in net-vm, which is
        # where avahi.enable is now set.
        enable = true;
        hostnamePath = "/var/common/hostname";
      };

      fmo-onboarding-agent = {
        enable = true;
        certs_path = "/var/lib/fogdata/certs";
        config_path = "/var/lib/fogdata";
        token_path = "/var/lib/fogdata";
        hostname_path = "/var/lib/fogdata";
        ip_path = "/var/lib/fogdata";
        post_install_path = "/var/lib/fogdata/certs";
      };
    };
  };
}
