# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.dac-kms-enrolment;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.dac-kms-enrolment = {
    enable = mkEnableOption "Enable KMS enrolment service on system";

    config_file = mkOption {
      description = "Path to configuration file";
      type = types.path;
      default = "/var/lib/fogdata/kms/enrolment.conf";
    };

    log_level = mkOption {
      description = "Set the log level";
      type = types.str;
      default = "debug";
    };

    kms_address = mkOption {
      description = "Set KMS endpoint address";
      type = types.str;
      default = "100.66.96.2";
    };

    certificates_path = mkOption {
      description = "Path to certificates received from KMS";
      type = types.path;
      default = "/var/lib/fogdata/kms/certs";
    };

    key_path = mkOption {
      description = "Path to generated key-pair";
      type = types.path;
      default = "/var/lib/fogdata/kms/keys";
    };

    key_source = mkOption {
      description = "How the key-pair is generated";
      type = types.str;
      default = "File";
    };

    serial_number_file = mkOption {
      description = "The hardware-based device ID file";
      type = types.path;
      default = "/var/common/hardware-id.txt";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.dac-kms-enrolment =
      let
        kmsEnrolment = pkgs.writeShellApplication {
          name = "kms-enrolment";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.kms-enrolment
          ];
          text = ''
            # Get device ID from hardware
            device_id=$(cat ${cfg.serial_number_file})

            # Create required directories
            [ ! -d ${cfg.certificates_path} ] && mkdir -p ${cfg.certificates_path}
            [ ! -d ${cfg.key_path} ] && mkdir -p ${cfg.key_path}

            # Write config file
            cat > ${cfg.config_file} << EOF
            log_level = "${cfg.log_level}"
            kms_address = "${cfg.kms_address}"
            certificate_path = "${cfg.certificates_path}"
            key_source = "${cfg.key_source}"
            key_path = "${cfg.key_path}"
            EOF

            # Start KMS enrolment
            ${pkgs.kms-enrolment}/bin/enroll-mc --config-file ${cfg.config_file} --serial-number "$device_id"
          '';
        };
      in
      {
        description = "KMS enrolment";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        after = [
          "fmo-hardware-id-manager.service" # Writes the hardware ID to /var/common/hardware-id.txt
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${kmsEnrolment}/bin/kms-enrolment";
          RemainAfterExit = true;
          Restart = "on-failure";
        };
        unitConfig = {
          ConditionPathExists = [
            "${cfg.serial_number_file}"
          ];
        };
      };
  };
}
