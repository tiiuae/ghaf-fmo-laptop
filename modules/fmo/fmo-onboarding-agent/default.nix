# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.fmo-onboarding-agent;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
in
{
  options.services.fmo-onboarding-agent = {
    enable = mkEnableOption "Install and setup onboarding-agent on system";

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
      default = "/var/lib/fogdata";
    };

    log_file_path = mkOption {
      description = "Path to log file";
      type = types.path;
      default = "/var/lib/fogdata/onboarding-agent.log";
    };

    enable_dac = mkEnableOption "Enable DAC verification";

    dac_file_path = mkOption {
      description = "Path to Device Assembly Card (DAC) file";
      type = types.path;
      default = "/var/lib/fogdata/dac/dac.json";
    };
  };

  config = mkIf cfg.enable {

    systemd.services.setup-onboarding-agent =
      let
        onboardingSetup = pkgs.writeShellApplication {
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

            # Write config.yaml file
            cat > ${cfg.env_path}/config.yaml << EOF
            ${if cfg.enable_dac then "EnableDAC: true" else ""}
            TLS: true
            MDNS: true
            NatsEndpointFile: "${cfg.certs_path}/service_nats_url.txt"
            Device:
              Type: "laptop"
              Alias: ""
              Architecture: "linux/amd64"
              Topology: "recon"
              IpAddressFile: "${cfg.ip_path}/ip-address"
              HostnameFile: "${cfg.hostname_path}/hostname"
              ConfigurationFile: "${cfg.config_path}/docker-compose.yml"
              ConfigurationTemplateFile: "${cfg.config_path}/docker-compose.mustache"
              NatsLeafConfigurationFile: "${cfg.certs_path}/leaf.conf"
              ${if cfg.enable_dac then "AssemblyCardFile: \"${cfg.dac_file_path}\"" else ""}
            Identity:
              CaCertFile: "${cfg.certs_path}/identity_ca.crt"
              CertFile: "${cfg.certs_path}/identity.crt"
              KeyFile: "${cfg.certs_path}/identity.key"
              SerialNumberFile: "${cfg.certs_path}/serial_number.txt"
              CertificateRequestFile: "${cfg.certs_path}/identity.csr"
              File: "${cfg.certs_path}/device_id.json"
              FleetClusterCertificateRequestFile: "${cfg.certs_path}/fleet.csr"
              FleetLeafCertificateFile: "${cfg.certs_path}/fleet.crt"
              FleetLeafCaFile: "${cfg.certs_path}/fleet_ca.crt"
              SwarmCaCertificateRequestFile: "${cfg.certs_path}/swarm.csr"
              SwarmCaFile: "${cfg.certs_path}/swarm.crt"
              SwarmKeyFile: "${cfg.certs_path}/swarm.key"
              SwarmRootCaFile: "${cfg.certs_path}/swarm_root_ca.crt"
            Secrets:
              AuthTokenFile: "${cfg.token_path}/PAT.pat"
              UtmSecretFile: "${cfg.certs_path}/utm-client-secret.txt"
            EOF
          '';
        };
      in
      {
        description = "Setup onboarding agent";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = [
          "/var/lib/fogdata"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${onboardingSetup}/bin/setup-onboarding-agent";
          RemainAfterExit = true;
        };
      };
  };
}
