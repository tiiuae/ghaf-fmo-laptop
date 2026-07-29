# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.fmo-certs-distribution-service-host;

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    length
    genList
    zipListsWith
    concatStringsSep
    ;

  mkClintCert = client-path: n: ''
    echo "Generate private key for the client-${n}"
    ${pkgs.openssl}/bin/openssl genpkey -algorithm RSA -out ${client-path}/client.key
    echo "Create a certificate signing request (CSR) for the client-${n}"
    ${pkgs.openssl}/bin/openssl req -new -key ${client-path}/client.key -out ${client-path}/client.csr -subj "/CN=client-${n}"
    echo "Sign the client CSR with the CA certificate-${n}"
    ${pkgs.openssl}/bin/openssl x509 -req -in ${client-path}/client.csr -CA ${cfg.ca-path}/ca.crt -CAkey ${cfg.ca-path}/ca.key \
      -CAcreateserial -out ${client-path}/client.crt -days 365 -sha256
  '';

  addIP = ip: "IP: ${ip}";

  numOfClients = genList toString (length cfg.clients-paths);

in
{
  options.services.fmo-certs-distribution-service-host = {
    enable = mkEnableOption "fmo-certs-distribution-service-host";

    ca-name = mkOption {
      type = types.str;
      description = "CA name";
      default = "";
    };

    ca-path = mkOption {
      type = types.str;
      description = ''
        Path to generate the CA key and certificate.

        This directory holds ca.key and must stay on the host - anything that
        can read it can mint certificates trusted by the whole mesh. Share
        `ca-public-path` with guests instead.
      '';
      default = "";
    };

    ca-public-path = mkOption {
      type = types.str;
      description = ''
        Path to publish the CA certificate alone, for sharing into guests.

        Only ca.crt is copied here; the key never leaves `ca-path`.
      '';
      default = "";
    };

    server-name = mkOption {
      type = types.str;
      description = "Server name, used as the CN of the server certificate";
      default = "";
    };

    server-path = mkOption {
      type = types.nullOr types.str;
      description = ''
        Path to generate a server certificate, or null to generate none.

        Only set this where something actually serves TLS from this host.
      '';
      default = null;
    };

    server-ips = mkOption {
      type = types.listOf types.str;
      description = "IPs to place in the server certificate's subjectAltName";
      default = [ ];
    };

    clients-paths = mkOption {
      type = types.listOf types.str;
      description = "Paths to generate clients certs";
      default = "";
    };
  };

  config = mkIf cfg.enable {
    systemd.services."openssl-certs-gen" =
      let
        keygenScript = pkgs.writeShellScriptBin "openssl-certs-gen" ''
          set -xeuo pipefail

          echo "Create CA dir"
          mkdir -pv ${cfg.ca-path}

          echo "Create published CA cert dir"
          mkdir -pv ${cfg.ca-public-path}

          echo "Create Clients certs dirs"
          for path in ${concatStringsSep " " cfg.clients-paths}; do
            mkdir -pv $path
          done

          echo "Generate private key for CA"
          ${pkgs.openssl}/bin/openssl genpkey -algorithm RSA -out ${cfg.ca-path}/ca.key
          # openssl honours the ambient umask, which leaves this 0644.
          chmod 0600 ${cfg.ca-path}/ca.key
          echo "Generate self-signed CA certificate"
          ${pkgs.openssl}/bin/openssl req -x509 -new -nodes -key ${cfg.ca-path}/ca.key -sha256 -days 365 -out ${cfg.ca-path}/ca.crt \
            -subj "/CN=${cfg.ca-name}"

          # Publish the CA certificate on its own, and share only this directory
          # with guests. They need ca.crt to verify the mesh; they must never see
          # ca.key, which stays in ${cfg.ca-path} on the host.
          install -m 0644 ${cfg.ca-path}/ca.crt ${cfg.ca-public-path}/ca.crt
          ${lib.optionalString (cfg.server-path != null) ''
            EXT_CONF="basicConstraints=CA:FALSE
                     keyUsage=digitalSignature,keyEncipherment
                     extendedKeyUsage=serverAuth
                     subjectAltName=${concatStringsSep ", " (map addIP cfg.server-ips)}"

            echo "Create Server cert dir"
            mkdir -pv ${toString cfg.server-path}

            echo "Generate private key for the server"
            ${pkgs.openssl}/bin/openssl genpkey -algorithm RSA -out ${toString cfg.server-path}/server.key
            echo "Create a certificate signing request (CSR) for the server"
            ${pkgs.openssl}/bin/openssl req -new -key ${toString cfg.server-path}/server.key -out ${toString cfg.server-path}/server.csr \
              -subj "/CN=${cfg.server-name}" \
              -addext "subjectAltName=${concatStringsSep ", " (map addIP cfg.server-ips)}"
            echo "Sign the server CSR with the CA certificate"
            ${pkgs.openssl}/bin/openssl x509 -req -in ${toString cfg.server-path}/server.csr -CA ${cfg.ca-path}/ca.crt -CAkey ${cfg.ca-path}/ca.key \
              -CAcreateserial -out ${toString cfg.server-path}/server.crt -days 365 -sha256 \
                -extfile <(printf "$EXT_CONF")
          ''}
          echo "Generate certs for clients"
          ${concatStringsSep "\n" (zipListsWith mkClintCert cfg.clients-paths numOfClients)}
        '';
      in
      {
        enable = true;
        description = "Generate encryption certs";
        path = [ keygenScript ];
        wantedBy = [ "microvms.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StandardOutput = "journal";
          StandardError = "journal";
          ExecStart = "${keygenScript}/bin/openssl-certs-gen";
        };
      };
  };
}
