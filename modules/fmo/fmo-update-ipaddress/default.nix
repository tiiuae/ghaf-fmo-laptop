# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fmo-update-ipaddress;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    concatMapStringsSep
    ;

  mkNmTemplate = file: cidr: uuid: device: method: ''
    cat <<EOF > $NM_FILEPATH/${file}
    [connection]
    id=$IP${cidr}
    uuid=${uuid}
    type=ethernet
    autoconnect-priority=-999
    interface-name=${device}
    timestamp=1695890834

    [ethernet]
    mtu=1372

    [ipv4]
    address1=$IP${cidr}
    method=${method}

    [ipv6]
    addr-gen-mode=default
    method=auto

    [proxy]
    EOF
    chmod 0600 $NM_FILEPATH/${file}
  '';
in
{
  options.services.fmo-update-ipaddress = {
    enable = mkEnableOption "";
    ipAddressPath = mkOption {
      description = "Path to the ipaddress file";
      type = types.path;
      default = "/var/common/ip-address";
    };
    nmTemplates = mkOption {
      description = "NetworkManager templates";
      type = types.listOf types.attrs;
      default = [
        {
          uuid = "4f3b719f-6a2a-4c7b-95be-afc4c912ca95";
          device = "mesh0";
          file = "WiredMesh.nmconnection";
          method = "manual";
          cidr = "/24";
        }
        {
          uuid = "5fbbc161-ac51-49ef-bd02-85ee6d016190";
          device = "externalmesh0";
          file = "ExternalMesh.nmconnection";
          method = "manual";
          cidr = "/24";
        }
      ];
    };
    restartUnits = mkOption {
      description = "Services to restart with IP address change";
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {

    # Add fmo-update-ipaddress service to givc
    givc.sysvm.services = [
      "fmo-update-ipaddress.service"
    ];

    systemd.services.fmo-update-ipaddress =
      let
        updateIpaddressScript = pkgs.writeShellApplication {
          name = "update-ipaddress";
          runtimeInputs = [
            pkgs.gawk
            pkgs.coreutils
          ];
          text = ''
            # Generate NetworkManager templates
            IP=$(gawk '{print $1}' ${cfg.ipAddressPath})
            [ -z "$IP" ] && echo "IP address file is empty" && exit 1
            NM_FILEPATH=/etc/NetworkManager/system-connections/
            [ ! -d $NM_FILEPATH ] && echo "Networkmanager connections path does not exist" && exit 1
            ${concatMapStringsSep "\n" (
              t: "${mkNmTemplate t.file t.cidr t.uuid t.device t.method}"
            ) cfg.nmTemplates}

            # Restart units
            ${concatMapStringsSep "\n" (u: "systemctl restart ${u}") cfg.restartUnits}
          '';
        };
      in
      {
        description = "Update IP address and network manager templates";
        enable = true;
        serviceConfig = {
          type = "oneshot";
          ExecStart = "${updateIpaddressScript}/bin/update-ipaddress";
        };
      };
  };
}
