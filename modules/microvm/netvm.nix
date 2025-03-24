# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  ...
}:
{
  imports = [
    ../fmo/fmo-update-hostname
    ../fmo/fmo-update-ipaddress
    ../fmo/dynamic-portforwarding-service
  ];
  config = {

    # Adjust the MTU for the ethint0 interface
    systemd.network.links."10-ethint0".extraConfig = "MTUBytes=1372";

    givc.sysvm.services = [
      "reboot.target"
      "poweroff.target"
    ];

    # Services
    services = {

      # Avahi
      avahi = {
        enable = true;
        nssmdns4 = true;
        reflector = true;
      };

      fmo-update-ipaddress = {
        enable = true;
        ipAddressPath = "/var/common/ip-address";
        restartUnits = [
          "NetworkManager.service"
        ];
      };

      # TODO This is currently non-functional
      # dynamic-portforwarding-service = {
      #   enable = true;
      #   ipaddress-path = "/var/common/ip-address";
      #   config-path = "/etc/NetworkManager/system-connections/dpf.config";
      #   configuration = [
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "4222";
      #       sport = "4222";
      #       proto = "tcp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "4222";
      #       sport = "4222";
      #       proto = "udp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "7222";
      #       sport = "7222";
      #       proto = "tcp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "7222";
      #       sport = "7222";
      #       proto = "udp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "6422";
      #       sport = "6422";
      #       proto = "tcp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "6423";
      #       sport = "6423";
      #       proto = "udp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "123";
      #       sport = "123";
      #       proto = "udp";
      #     }
      #     {
      #       dip = hosts.docker-vm.ipv4;
      #       dport = "123";
      #       sport = "123";
      #       proto = "tcp";
      #     }
      #   ];
      # };
    }; # services

    microvm = {
      volumes = [
        {
          image = "/persist/tmp/netvm_internal.img";
          mountPoint = "/var/lib/internal";
          size = 10240;
          autoCreate = true;
          fsType = "ext4";
        }
      ];

      shares = [
        {
          source = "/persist/common";
          mountPoint = "/var/common";
          tag = "common_share_netvm";
          proto = "virtiofs";
          socket = "common_share_netvm.sock";
        }
        {
          source = "/run/certs/nats/clients/netvm";
          mountPoint = "/var/lib/nats/certs";
          tag = "nats_netvm_certs";
          proto = "virtiofs";
          socket = "nats_netvm_certs.sock";
        }
        {
          source = "/run/certs/nats/ca";
          mountPoint = "/var/lib/nats/ca";
          tag = "nats_netvm_ca_certs";
          proto = "virtiofs";
          socket = "nats_netvm_ca_certs.sock";
        }
      ];
    }; # microvm

  };
}
