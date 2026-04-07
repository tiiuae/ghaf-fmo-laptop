# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# FMO service modules
# These define service options (e.g., services.fmo-dci.enable)
#
{
  flake.nixosModules = {
    # Combined module for host (all services)
    fmo-services.imports = [
      ./fmo-dci-service
      ./fmo-firewall
      ./fmo-certs-distribution-host
      ./fmo-dci-passthrough
      ./fmo-onboarding-agent
      ./fmo-update-hostname
      ./fmo-docker-networking
    ];
  };
}
