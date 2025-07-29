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
    any
    optionals
    optionalString
    mkForce
    ;

  rmDesktopEntry =
    pkg:
    pkg.overrideAttrs (
      old:
      let
        pInst = if (old ? postInstall) then old.postInstall else "";
      in
      {
        postInstall = pInst + "rm -rf \"$out/share/applications\"";
      }
      // lib.optionalAttrs (old ? buildCommand) {
        buildCommand = old.buildCommand + "rm -rf \"$out/share/applications\"";
      }
    );
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
        enable = any (d: d.vendorId == "10de") config.ghaf.common.hardware.gpus;
      };

      intel-setup = {
        enable = any (d: d.vendorId == "8086") config.ghaf.common.hardware.gpus;
      };
    };

    environment.systemPackages = [
      google-chrome
      pkgs.wl-screenrec
      pkgs.slurp
      pkgs.resources
      pkgs.wf-recorder
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
