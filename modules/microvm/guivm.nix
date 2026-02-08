# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    optionals
    optionalString
    mkForce
    rmDesktopEntry
    ;

  nvidiaEnabled = config.ghaf.graphics.nvidia-setup.enable;
  chromeExtraArgs =
    optionalString (!nvidiaEnabled) ",UseOzonePlatform"
    + optionalString nvidiaEnabled ",VaapiOnNvidiaGPUs";

  google-chrome = (rmDesktopEntry pkgs.google-chrome).override {
    commandLineArgs = [
      # Hardware video encoding on Chrome on Linux.
      # See chrome://gpu to verify.
      # Enable H.265 video codec support.
      "--enable-features=AcceleratedVideoDecodeLinuxGL,VaapiVideoDecoder,VaapiVideoEncoder,WebRtcAllowH265Receive,VaapiIgnoreDriverChecks,WaylandLinuxDrmSyncobj${chromeExtraArgs}"
      "--force-fieldtrials=WebRTC-Video-H26xPacketBuffer/Enabled"
      "--enable-zero-copy"
    ]
    ++ optionals (!nvidiaEnabled) [ "--ozone-platform=wayland" ];
  };

in
{
  config = {
    ghaf.graphics = {

      nvidia-setup = {
        enable = lib.any (d: d.vendorId == "10de") config.ghaf.common.hardware.gpus;
      };

      intel-setup = {
        enable = lib.any (d: d.vendorId == "8086") config.ghaf.common.hardware.gpus;
      };
    };

    environment.systemPackages = [
      google-chrome
      pkgs.resources
      pkgs.nvtopPackages.full
    ];

    programs.firefox = {
      enable = true;
      package = rmDesktopEntry pkgs.firefox;
    };

    # A greetd service override is needed to run Google Chrome.
    # Since Google Chrome uses GPU resources, we require less
    # hardening for greetd service compared to ghaf.
    systemd.services.greetd.serviceConfig = {
      RestrictNamespaces = mkForce false;
      SystemCallFilter = mkForce [
        "~@cpu-emulation"
        "~@debug"
        "~@module"
        "~@obsolete"
        "~@reboot"
        "~@swap"
      ];
    };
  };
}
