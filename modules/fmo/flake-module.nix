# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  flake.nixosModules = {
    # Dockervm specific fmo services
    fmo-services.imports = [
      ./fmo-dci-service
      ./fmo-firewall
      ./fmo-dci-passthrough
      ./fmo-onboarding-agent
      ./fmo-nats-server
      ./fmo-update-hostname
      ./hardware-id-manager
    ];

    # Host specific fmo services
    fmo-services-host.imports = [
      ./fmo-certs-distribution-host
    ];
  };
}
