# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  flake.nixosModules = {
    fmo-services.imports = [
      ./fmo-dci-service
      ./fmo-firewall
      ./fmo-certs-distribution-host
      ./fmo-dci-passthrough
      ./fmo-onboarding-agent
      ./fmo-nats-server
      ./fmo-update-hostname
      ./hardware-id-manager
    ];
  };
}
