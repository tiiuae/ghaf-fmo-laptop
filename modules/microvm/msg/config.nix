# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkForce;
in
{
  config = {
    environment.systemPackages = [
      pkgs.vim
      pkgs.tcpdump
      pkgs.gpsd
      pkgs.natscli
      pkgs.nats-top
      pkgs.nats-server
    ];

    givc.appvm.enable = mkForce false;
    givc.sysvm = {
      enable = true;
      services = [ "fmo-nats-server.service" ];
    };

    ghaf.storagevm = {
      maximumSize = 20 * 1024;
      directories = [
        {
          directory = "/var";
          user = "root";
          group = "root";
          mode = "0755";
        }
      ];
    };

    microvm = {
      shares = [
        {
          source = "/persist/common";
          mountPoint = "/var/common";
          tag = "common_share_msgvm";
          proto = "virtiofs";
          socket = "common_share_msgvm.sock";
        }
        {
          source = "/run/certs/nats/server";
          mountPoint = "/var/lib/nats/certs";
          tag = "nats_certs";
          proto = "virtiofs";
          socket = "nats_certs.sock";
        }
        {
          source = "/run/certs/nats/ca";
          mountPoint = "/var/lib/nats/ca";
          tag = "nats_ca";
          proto = "virtiofs";
          socket = "nats_ca.sock";
        }
      ];
    };

    services = {
      avahi = {
        enable = true;
        nssmdns4 = true;
        ipv4 = true;
        ipv6 = false;
        publish = {
          enable = true;
          domain = true;
          addresses = true;
          workstation = true;
        };
        domainName = "msgvm";
      };

      fmo-update-hostname = {
        enable = true;
        hostnamePath = "/var/common/hostname";
      };

      fmo-nats-server = {
        enable = true;
        port = 4222;
        settings = {
          http = 8222;
          tls = {
            cert_file = "/var/lib/nats/certs/server.crt";
            key_file = "/var/lib/nats/certs/server.key";
            ca_file = "/var/lib/nats/ca/ca.crt";
            verify_and_map = true;
          };
          log_file = "/var/lib/nats/nats-server.log";
          logtime = true;
        };
      };
    };

    ghaf.firewall.enable = false;
  };
}
