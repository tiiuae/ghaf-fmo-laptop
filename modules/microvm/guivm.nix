# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  lib,
  ...
}:
let
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
      # Turn on vulkan support
      "--enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,WebRtcAllowH265Receive,Vulkan,VaapiIgnoreDriverChecks,DefaultANGLEVulkan,VulkanFromANGLE"
      "--force-fieldtrials=WebRTC-Video-H26xPacketBuffer/Enabled"
    ];
  };

  firefox-beta = rmDesktopEntry pkgs.firefox-beta;
in
{
  config = {
    ghaf.graphics.nvidia-setup = {
      enable = true;
      vaapi.firefox.av1Support = true;
    };

    environment.systemPackages = [
      google-chrome
    ];

    programs.firefox = {
      enable = true;
      package = firefox-beta;
    };
  };
}
