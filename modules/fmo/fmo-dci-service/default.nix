# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.fmo-dci;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  preload_path = ./images;
in
{
  options.services.fmo-dci = {
    enable = mkEnableOption "Docker Compose Infrastructure service";

    pat-path = mkOption {
      type = types.str;
      description = "Path to PAT .pat file";
    };
    compose-path = mkOption {
      type = types.str;
      description = "Path to docker-compose's .yml file";
    };
    update-path = mkOption {
      type = types.str;
      description = "Path to docker-compose's .yml file for update";
    };
    backup-path = mkOption {
      type = types.str;
      description = "Path to docker-compose's .yml file for backup";
    };
    preloaded-images = mkOption {
      type = types.str;
      description = "Preloaded docker images file names separated by spaces";
    };
    docker-url = mkOption {
      type = types.str;
      default = "";
      description = "Default container repository URL to use";
    };
    docker-url-path = mkOption {
      type = types.str;
      default = "";
      description = "Path to docker url file";
    };
    docker-mtu = mkOption {
      type = types.int;
      default = 1500;
      description = "Docker default MTU size";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.docker-compose
    ];

    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        mtu = cfg.docker-mtu;
        data-root = "/var/lib/docker";
      };
    };

    systemd.paths.fmo-dci = {
      description = "Monitor docker compose meta files for changes";
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathModified = [
        cfg.pat-path
        cfg.compose-path
      ];
    };

    systemd.services.fmo-dci = {
      script = ''
        USR=$(${pkgs.gawk}/bin/gawk '{print $1}' ${cfg.pat-path} || echo "")
        PAT=$(${pkgs.gawk}/bin/gawk '{print $2}' ${cfg.pat-path} || echo "")
        DCPATH=$(echo ${cfg.compose-path})
        UPDPATH=$(echo ${cfg.update-path})
        BCPPATH=$(echo ${cfg.backup-path})
        PRELOAD_PATH=$(echo ${preload_path})
        DOCKER_URL=$(echo ${cfg.docker-url})
        DOCKER_URL_PATH=$(echo ${cfg.docker-url-path})

        if [ -e "$DOCKER_URL_PATH" ]; then
          DOCKER_URL=$(cat $DOCKER_URL_PATH)
        fi

        # Check if the update file exists
        if [ -e "$UPDPATH" ]; then
            echo "Update file exists. Proceeding with backup and update operations"

            # Backup the original file if it exists
            if [ -e "$DCPATH" ]; then
                echo "Stop docker-compose"
                ${pkgs.docker-compose}/bin/docker-compose -f $DCPATH down

                echo "Backing up the original file"
                mv "$DCPATH" "$BCPPATH"
            else
                echo "No original file to backup"
            fi

            # Move the new file to replace the original file
            mv "$UPDPATH" "$DCPATH"
            echo "Move completed successfully"
        else
            echo "Update file does not exist. No operations performed"
        fi

        echo "Login $DOCKER_URL"
        echo $PAT | ${pkgs.docker}/bin/docker login $DOCKER_URL -u $USR --password-stdin || echo "login to $DOCKER_URL failed continue as is"

        echo "Load preloaded docker images"
        for FNAME in ${cfg.preloaded-images}; do
          IM_NAME=''${FNAME%%.*}

          if test -f "$PRELOAD_PATH/$FNAME"; then
            echo "Preloaded image $FNAME exists"

            if ${pkgs.docker}/bin/docker images | grep $IM_NAME; then
              echo "Image already loaded to docker, skip..."
            else
              echo "There is no such image in docker, load $PRELOAD_PATH/$FNAME..."
              ${pkgs.docker}/bin/docker load < $PRELOAD_PATH/$FNAME || echo "Preload image $PRELOAD_PATH/$FNAME failed continue"
            fi
          else
            echo "Preloaded image $IM_NAME does not exist, skip..."
          fi
        done

        echo "Start docker-compose"
        ${pkgs.docker-compose}/bin/docker-compose -f $DCPATH up
      '';

      wantedBy = [ "multi-user.target" ];
      # If you use podman
      # after = ["podman.service" "podman.socket"];
      # If you use docker
      after = [
        "docker.service"
        "docker.socket"
      ];
      requires = [ "network-online.target" ];

      # Only run this service if provisioning is complete
      unitConfig.ConditionPathExists = [
        cfg.pat-path
        cfg.compose-path
      ];

      serviceConfig = {
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}
