# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.dac-nats-server;
  inherit (lib)
    mkEnableOption
    mkIf
    ;
in
{
  options.services.dac-nats-server = {
    enable = mkEnableOption "Enable DAC NATS server on the system";
  };

  config = mkIf cfg.enable {
    systemd.services.dac-nats-server = {
      description = "NATS server used for the communication between DAC agent and DAC server";
      wantedBy = [ "multi-user.target" ];
      before = [ "multi-user.target" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = "/run/current-system/sw/bin/nats-server --trace --debug";
        Restart = "on-failure";
      };
    };
  };
}