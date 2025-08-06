# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  imports = [
    ./hardware/flake-module.nix
    ./fmo/flake-module.nix
    ./profile/flake-module.nix
    ./dac/flake-module.nix
  ];

  flake.nixosModules = {
    host.imports = [ ./microvm/host.nix ];
    netvm.imports = [ ./microvm/netvm.nix ];
    guivm.imports = [ ./microvm/guivm.nix ];
    dockervm.imports = [ ./microvm/docker/vm.nix ];
    msgvm.imports = [ ./microvm/msg/vm.nix ];
  };
}
