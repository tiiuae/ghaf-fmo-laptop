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
  cfg = config.services.registration-agent-laptop;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.registration-agent-laptop = {
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
  };

  config = mkIf cfg.enable {

    systemd.services.setup-registration-agent =
      let
        registrationSetup = pkgs.writeShellApplication {
          name = "setup-registration-agent";
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
            [ ! -d ${cfg.post_install_path} ] && mkdir -p ${cfg.post_install_path}
            [ ! -d ${cfg.env_path} ] && mkdir -p ${cfg.env_path}

            # Write .env file
            cat > ${cfg.env_path}/.env << EOF
            AUTOMATIC_PROVISIONING=false
            TLS=true
            PROVISIONING_URL=
            DEVICE_ALIAS=
            DEVICE_IDENTITY_FILE=${cfg.certs_path}/identity.txt
            DEVICE_CONFIGURATION_FILE=${cfg.config_path}/docker-compose.yml
            DEVICE_AUTH_TOKEN_FILE=${cfg.token_path}/PAT.pat
            DEVICE_HOSTNAME_FILE=${cfg.hostname_path}/hostname
            DEVICE_ID_FILE=${cfg.certs_path}/device_id.txt
            FLEET_NATS_LEAF_CONFIG_FILE=${cfg.certs_path}/leaf.conf
            SERVICE_NATS_URL_FILE=${cfg.certs_path}/service_nats_url.txt
            SERVICE_IDENTITY_KEY_FILE=${cfg.certs_path}/identity.key
            SERVICE_IDENTITY_CERTIFICATE_FILE=${cfg.certs_path}/identity.crt
            SERVICE_IDENTITY_CA_FILE=${cfg.certs_path}/identity_ca.crt
            SERVICE_FLEET_LEAF_CERTIFICATE_FILE=${cfg.certs_path}/fleet.crt
            SERVICE_FLEET_LEAF_CA_FILE=${cfg.certs_path}/fleet_ca.crt
            SERVICE_SWARM_KEY_FILE=${cfg.certs_path}/swarm.key
            SERVICE_SWARM_CA_FILE=${cfg.certs_path}/swarm.crt
            IP_ADDRESS_FILE=${cfg.ip_path}/ip-address
            UTM_CLIENT_SECRET_FILE=${cfg.certs_path}/utm-client-secret
            RABBIT_MQ_SECRET_FILE=${cfg.certs_path}/rabbit-mq-secret
            POST_INSTALLATION_DIRECTORY=${cfg.post_install_path}
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
          ExecStart = "${registrationSetup}/bin/setup-registration-agent";
          RemainAfterExit = true;
        };
      };
  };
}
