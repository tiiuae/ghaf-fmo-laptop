# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.onboarding-agent;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.onboarding-agent = {
    enable = mkEnableOption "Install and setup registration-agent on system";

    certs_path = mkOption {
      description = "Path to certificate files, used for environment variables";
      type = types.path;
      default = "/var/lib/fogdata/certs";
    };

    config_path = mkOption {
      description = "Path to config file, docker-compose.yml, used for environment variables";
      type = types.path;
      default = "/var/lib/fogdata";
    };

    token_path = mkOption {
      description = "Path to token file, used for environment variables";
      type = types.path;
      default = "/var/lib/fogdata";
    };

    hostname_path = mkOption {
      description = "Path to hostname file, used for environment variables";
      type = types.path;
      default = "/var/lib/fogdata";
    };

    ip_path = mkOption {
      description = "Path to ip file, used for environment variables";
      type = types.path;
      default = "/var/lib/fogdata";
    };

    post_install_path = mkOption {
      description = "Path to certificates after installation";
      type = types.path;
      default = "/var/lib/fogdata/certs";
    };

    env_path = mkOption {
      description = "Path to create .env file";
      type = types.path;
      default = "${config.users.users.appuser.home}";
    };

    log_file_path = mkOption {
      description = "Path to log file";
      type = types.path;
      default = "${cfg.certs_path}/registration-agent.log";
    };
  };

  config = mkIf cfg.enable {

    systemd.services.setup-onboarding-agent =
      let
        registrationSetup = pkgs.writeShellApplication {
          name = "setup-onboarding-agent";
          runtimeInputs = [
            pkgs.coreutils
          ];
          text = ''
            # Create folders
            [ ! -d ${cfg.certs_path} ] && mkdir -p ${cfg.certs_path}
            [ ! -d ${cfg.config_path} ] && mkdir -p ${cfg.config_path}
            [ ! -d ${cfg.token_path} ] && mkdir -p ${cfg.token_path}
            [ ! -d ${cfg.hostname_path} ] && mkdir -p ${cfg.hostname_path}
            [ ! -d ${cfg.ip_path} ] && mkdir -p ${cfg.ip_path}
            [ ! -d ${cfg.env_path} ] && mkdir -p ${cfg.env_path}

            # Write .env file
            cat > ${cfg.env_path}/.env << EOF
            # Agent configuration
            TLS=true
            MDNS=true

            # Device configuration
            DEVICE_TYPE=laptop
            DEVICE_ALIAS=

            # Device identity
            IDENTITY_FILE=${cfg.certs_path}/device_id.json
            IDENTITY_SERIAL_NUMBER_FILE=${cfg.certs_path}/serial_number.txt

            # Connection endpoints
            PROVISIONING_URL=
            NATS_ENDPOINT_FILE=${cfg.certs_path}/service_nats_url.txt

            # Laptop specific configuration
            DEVICE_HOSTNAME_FILE=${cfg.hostname_path}/hostname
            DEVICE_IP_ADDRESS_FILE=${cfg.ip_path}/ip-address

            # FMO stack configuration
            DEVICE_NATS_LEAF_CONFIGURATION_FILE=${cfg.certs_path}/leaf.conf
            DEVICE_CONFIGURATION_FILE=${cfg.config_path}/docker-compose.yml
            DEVICE_CONFIGURATION_TEMPLATE_FILE=${cfg.config_path}/docker-compose.mustache

            # Identity certificates (Backbone certificates)
            IDENTITY_CERTIFICATE_REQUEST_FILE=${cfg.certs_path}/identity.csr
            IDENTITY_KEY_FILE=${cfg.certs_path}/identity.key
            IDENTITY_CERT_FILE=${cfg.certs_path}/identity.crt
            IDENTITY_CA_CERT_FILE=${cfg.certs_path}/identity_ca.crt

            # Fleet management NATS leaf node certificates
            IDENTITY_FLEET_CLUSTER_CERTIFICATE_REQUEST_FILE=${cfg.certs_path}/fleet.csr
            IDENTITY_FLEET_LEAF_CERTIFICATE_FILE=${cfg.certs_path}/fleet.crt
            IDENTITY_FLEET_LEAF_CA_FILE=${cfg.certs_path}/fleet_ca.crt

            # Swarm intermediate CA certificates
            IDENTITY_SWARM_CA_CERTIFICATE_REQUEST_FILE=${cfg.certs_path}/swarm.csr
            IDENTITY_SWARM_KEY_FILE=${cfg.certs_path}/swarm.key
            IDENTITY_SWARM_CA_FILE=${cfg.certs_path}/swarm.crt
            IDENTITY_SWARM_ROOT_CA_FILE=${cfg.certs_path}/swarm_root_ca.crt

            # Secrets
            SECRETS_AUTH_TOKEN_FILE=${cfg.token_path}/PAT.pat
            SECRETS_UTM_SECRET_FILE=${cfg.certs_path}/utm-client-secret
            EOF

            # Set permissions
            chown ${config.users.users.appuser.name}:${config.users.users.appuser.group} ${cfg.env_path}/.env
            # TODO is this necessary?
            chmod 666 ${cfg.env_path}/.env
          '';
        };
      in
      {
        description = "Setup registration agent";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = [
          "/var/lib/fogdata"
          "!${cfg.env_path}/.env"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${registrationSetup}/bin/setup-onboarding-agent --log-file ${cfg.log_file_path}";
          RemainAfterExit = true;
        };
      };
  };
}
