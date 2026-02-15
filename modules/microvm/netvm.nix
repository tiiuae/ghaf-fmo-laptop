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
  config = {
    services.udev.extraRules = ''
      SUBSYSTEM=="net", ACTION=="add", DRIVERS=="usb", \
           NAME="ueth%E{IFINDEX}"
    '';

    systemd.network.links."10-ethint0".extraConfig = "MTUBytes=1372";

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

      networks = {
        "30-ueth" = {
          matchConfig.Name = "ueth*";
          vlan = [ "vlan_control" ];
          networkConfig.LinkLocalAddressing = "no";
          linkConfig.RequiredForOnline = "carrier";
          addresses = [ { Address = "${ueth-ip}"; } ];
          routes = [
            {
              Destination = "${ueth-kmsip}";
              Gateway = "${ueth-gwip}";
            }
          ];
        };
        "40-vlan_control" = {
          matchConfig.Name = "vlan_control";
          addresses = [ { Address = "192.168.254.200/24"; } ];
        };
      };
    };

    environment.systemPackages = [ pkgs.vnstat ];

    ghaf.firewall.attack-mitigation.ping.rule = {
      burstNum = 5;
      maxPacketFreq = "2/s";
    };

    services = {
      vnstat.enable = true;

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
    };

    ghaf.storagevm.directories = [
      {
        directory = "/var/lib/internal";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];

    microvm = {
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
    };
  };
}
