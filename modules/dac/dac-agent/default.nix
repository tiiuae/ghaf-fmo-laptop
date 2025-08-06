# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.dac-agent;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.dac-agent = {
    enable = mkEnableOption "Enable DAC agent service on system";

    env_path = mkOption {
      description = "Path to the DAC agent configuration file";
      type = types.path;
      default = "/var/lib/fogdata/dac";
    };

    log_level = mkOption {
      description = "Set the log level";
      type = types.str;
      default = "debug";
    };

    nats_endpoint = mkOption {
      description = "The NATS server the agent will communicate with the server to receive the DAC";
      type = types.str;
      default = "localhost";
    };

    serial_number_file = mkOption {
      description = "The hardware-based device ID file";
      type = types.path;
      default = "/var/common/hardware-id.txt";
    };

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
  };
  config = mkIf cfg.enable {

    systemd.services.setup-dac-agent =
      let
        agentSetup = pkgs.writeShellApplication {
          name = "setup-dac-agent";
          runtimeInputs = [
            pkgs.coreutils
          ];
          text = ''
            # Get device ID from hardware
            device_id=$(cat ${cfg.serial_number_file})

            # Create required directories
            [ ! -d ${cfg.env_path} ] && mkdir -p ${cfg.env_path}
            [ ! -d ${cfg.dac_store_path} ] && mkdir -p ${cfg.dac_store_path}
            [ ! -d ${cfg.key_path} ] && mkdir -p ${cfg.key_path}

            # Write ENV file
            cat > ${cfg.env_path}/dac-agent.env << EOF
            LOG_LEVEL=${cfg.log_level}
            MOCK=false
            DAC_STORE_PATH=${cfg.dac_store_path}
            KEY_PATH=${cfg.key_path}
            PMC_SERIAL_NUMBER_FILE=${cfg.serial_number_file}
            DEVICE_ID=$device_id
            NATS_HOST=${cfg.nats_endpoint}
            EOF
          '';
        };
      in
      {
        description = "Setup DAC agent";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = [
          "/var/lib/fogdata"
          "${cfg.serial_number_file}"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${agentSetup}/bin/setup-dac-agent";
          RemainAfterExit = true;
        };
      };

    systemd.services.dac-agent = {
      description = "DAC agent";
      wantedBy = [ "multi-user.target" ];
      before = [ "multi-user.target" ];
      after = [ 
        "fmo-hardware-id-manager.service" # Writes the hardware ID to /var/common/hardware-id.txt
        "setup-dac-agent.service" # Sets up DAC agent configuration
        "dac-nats-server.service"
      ];
      serviceConfig = {
        Type = "exec";
        ExecStart = "${pkgs.device-assembly-agent}/bin/device-assembly-agent";
        Restart = "on-failure";
        EnvironmentFile = "${cfg.env_path}/dac-agent.env";
      };
      unitConfig = {
        ConditionPathExists = [
          "${cfg.env_path}"
          "${cfg.dac_store_path}"
          "${cfg.key_path}"
        ];
      };
    };
  };
}