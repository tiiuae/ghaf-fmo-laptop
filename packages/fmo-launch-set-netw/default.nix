# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  writeShellApplication,
  fmo-set-netw-con,
}:
writeShellApplication {
  name = "fmo-launch-set-netw";

  bashOptions = [ ];

  runtimeInputs = [
    fmo-set-netw-con
  ];

  text = ''
    set +euo pipefail

    launch_set_network_con() {
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbusproxy_net.sock fmo-set-netw-con
    }

    launch_set_network_con
  '';

  meta = {
    description = "Script for launching the script in net-vm for setting connection to a mesh network.";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
