# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.fmo-dac-agent;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.fmo-dac-agent = {
    enable = mkEnableOption "Enable DAC agent service on system";

    dac_store_path = mkOption {
      description = "Path to DAC directory, used to store the DAC file";
      type = types.path;
      default = "/var/lib/fogdata/dac";
    };

    key_path = mkOption {
      description = "Path to DAC key directory, used to store the public key file";
      type = types.path;
      default = "/var/lib/fogdata/dac";
    };

    mock = mkEnableOption "Mock agent instead of using the hardware device ID";

    serial_number_file = mkOption {
      description = "Path to the device serial number, used as device ID";
      type = types.path;
      default = "/persist/common/hardware-id.txt";
    };

    log_level = mkOption {
      description = "Log level";
      type = types.str;
      default = "debug";
    };

    nats_endpoint = mkOption {
      description = "NATS endpoint";
      type = types.str;
      default = "nats://localhost:4222";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.dac-agent =
      let
        dacAgent = pkgs.writeShellApplication {
          name = "dac-agent";
          runtimeInputs = [
            pkgs.coreutils
          ];
          text = ''
            # Create folders
            [ ! -d ${cfg.dac_store_path} ] && mkdir -p ${cfg.dac_store_path}
            [ ! -d ${cfg.key_path} ] && mkdir -p ${cfg.key_path}

            # Read device ID from hardware
            # Write the systemd configuration file
            cat > ${cfg.dac_store_path}/dac.conf << EOF
            NATS_HOST=${cfg.nats_endpoint}
            DEVICE_ID=${pkgs.coreutils}/bin/cat ${cfg.serial_number_file}
            DAC_STORE_PATH=${cfg.dac_store_path}
            KEY_PATH=${cfg.key_path}
            PMC_SERIAL_NUMBER_FILE=${cfg.serial_number_file}
            LOG_LEVEL=${cfg.log_level}
            MOCK=${toString cfg.mock}
            EOF
          '';
        };
      in
      {
        description = "DAC agent";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = [
          "/var/lib/fogdata"
        ];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${dacAgent}/bin/dac-agent";
          Restart = "on-failure";
          EnvironmentFile = "${cfg.dac_store_path}/dac.conf";
        };
      };
  };
}