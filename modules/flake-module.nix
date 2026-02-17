# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  imports = [
    ./hardware/flake-module.nix
    ./fmo/flake-module.nix
    ./profile/flake-module.nix
  ];

  flake.nixosModules = {
    host.imports = [ ./microvm/host.nix ];
    guivm.imports = [ ./microvm/guivm.nix ];
    netvm.imports = [ ./microvm/netvm.nix ];
    dockervm.imports = [ (import ./microvm/docker/vm.nix { inherit inputs; }) ];
    docker-vm-services.imports = [
      ./fmo/fmo-dci-service
      ./fmo/fmo-dci-passthrough
      ./fmo/fmo-onboarding-agent
      ./fmo/fmo-update-hostname
      ./fmo/fmo-docker-networking
    ];
    netvm-services.imports = [
      ./fmo/fmo-update-hostname
      ./fmo/fmo-firewall
    ];
  };
}
