# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  ...
}:
let
  inherit (config.ghaf.networking) hosts;
  ueth-kmsip = "100.66.96.2/32";
  ueth-gwip = "192.168.101.254";
  ueth-ip = "192.168.101.200/24";
in
{
  imports = [
    ../fmo/fmo-update-hostname
    ../fmo/fmo-firewall
    ../dac/dac-firewall
  ];
  config = {

    #renaming usb ethernet adapters
    services.udev.extraRules = ''
      SUBSYSTEM=="net", ACTION=="add", DRIVERS=="usb", \
           NAME="ueth%E{IFINDEX}"
    '';

    # Adjust the MTU for the ethint0 interface
    systemd.network.links."10-ethint0".extraConfig = "MTUBytes=1372";

    # Create vlan
    systemd.network = {
      enable = true;
      netdevs = {
        "20-vlan_control" = {
          netdevConfig = {
            Kind = "vlan";
            Name = "vlan_control";
          };
          vlanConfig.Id = 100;
        };
      };

      # NOTE: this config will assign same vlan for
      # every usb-eth-adapters. That's why you have to
      # configure differently if you want to plug in
      # multiple usb-eth-adapters
      networks = {
        "30-ueth" = {
          matchConfig.Name = "ueth*";
          # tag vlan on this link
          vlan = [
            "vlan_control"
          ];
          networkConfig.LinkLocalAddressing = "no";
          linkConfig.RequiredForOnline = "carrier";

          addresses = [
            { Address = "${ueth-ip}"; }
          ];

          routes = [
            {
              Destination = "${ueth-kmsip}";
              Gateway = "${ueth-gwip}";
            }
          ];
        };
        "40-vlan_control" = {
          matchConfig.Name = "vlan_control";
          addresses = [
            { Address = "192.168.244.200/24"; }
          ];
          # add relevant configuration here
        };
      };
    };

    environment.systemPackages = [
      pkgs.vnstat
    ];

    # Firewall attack mitigation configuration
    ghaf.firewall.attack-mitigation.ping.rule = {
      burstNum = 5;
      maxPacketFreq = "2/s";
    };

    # Services
    services = {

      # enable the network monitoring service
      vnstat.enable = true;

      # Avahi
      avahi = {
        enable = true;
        nssmdns4 = true;
        reflector = true;
        publish = {
          enable = true;
          domain = true;
          addresses = true;
        };
        extraServiceFiles = {
          ntp = ''
            <service-group>
              <name>NTP Server</name>
              <service>
                <type>_ntp._udp</type>
                <port>123</port>
              </service>
            </service-group>
          '';
        };
      };

      fmo-firewall = {
        enable = true;
        mtu = 1372;
        configuration = [
          {
            dip = hosts.docker-vm.ipv4;
            dport = "4222";
            sport = "4222";
            proto = "tcp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "4222";
            sport = "4222";
            proto = "udp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "7222";
            sport = "7222";
            proto = "tcp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "7222";
            sport = "7222";
            proto = "udp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "6422";
            sport = "6422";
            proto = "tcp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "6423";
            sport = "6423";
            proto = "udp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "123";
            sport = "123";
            proto = "udp";
          }
          {
            dip = hosts.docker-vm.ipv4;
            dport = "123";
            sport = "123";
            proto = "tcp";
          }
        ];
      };

      dac-firewall = {
        enable = true;
        mtu = 1372;
        ip = "192.168.101.200/24";
        kmsip = "100.66.96.2/32";
        gwip = "192.168.101.254";
      };

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
