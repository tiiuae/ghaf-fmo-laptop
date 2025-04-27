# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) any;

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

  google-chrome = (rmDesktopEntry pkgs.google-chrome).override {
    commandLineArgs = [
      # Hardware video encoding on Chrome on Linux.
      # See chrome://gpu to verify.
      # Enable H.265 video codec support.
      "--enable-features=AcceleratedVideoDecodeLinuxGL,UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,WebRtcAllowH265Receive,VaapiIgnoreDriverChecks,WaylandLinuxDrmSyncobj"
      "--ozone-platform=wayland"
      "--force-fieldtrials=WebRTC-Video-H26xPacketBuffer/Enabled"
      "--enable-zero-copy"
    ];
  };

in
{
  config = {
    ghaf.graphics.nvidia-setup = {
      enable = any (d: d.vendorId == "10de") config.ghaf.common.hardware.gpus;
    };

    #Primary drivers for the integrated GPU should not be enabledd for prime case
    ghaf.graphics.intel-setup = {
      enable = !config.ghaf.graphics.nvidia-setup.enable;
    };

    environment.systemPackages = [
      google-chrome
    ];

    programs.firefox = {
      enable = true;
      package = rmDesktopEntry pkgs.firefox;
    };

    ghaf.ghaf-audio = {
      enable = true;
      useTunneling = false;
      inherit (config.system) name;
    };
  };
}
