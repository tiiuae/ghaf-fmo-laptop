# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  flake.nixosModules = {
    dac-services.imports = [
      ./dac-agent
      ./dac-kms-enrolment
    ];
  };
}
