# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  config,
  lib,
  ...
}:
let
  cfg = config.fmo.appvms.msg;
in
{
  _file = ./vm.nix;

  options.fmo.appvms.msg = {
    enable = lib.mkEnableOption "FMO MSG (NATS Server) App VM";
  };

  config = lib.mkIf (cfg.enable && config.ghaf.profiles.laptop-x86.enable or false) {
    ghaf.virtualization.microvm.appvm.vms.msg = {
      enable = lib.mkDefault true;

      evaluatedConfig = config.ghaf.profiles.laptop-x86.mkAppVm {
        name = "msg";
        mem = 2048;
        vcpu = 2;
        borderColor = "#000000";
        applications = [ ];
        extraModules = [
          inputs.self.nixosModules.msg-vm-services
          ./config.nix
        ];
      };
    };

    services.fmo-certs-distribution-service-host.server-ips = [
      config.ghaf.networking.hosts.msg-vm.ipv4
    ];
  };
}
