# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  ...
}:
{
  config = {
    ghaf.graphics.nvidia-setup = {
      enable = true;
      vaapi.firefox.av1Support = true;
    };

    environment.systemPackages = with pkgs; [
      (google-chrome.override {
        commandLineArgs = [
          # Hardware video encoding on Chrome on Linux.
          # See chrome://gpu to verify.
          # Enable H.265 video codec support.
          # Turn on vulkan support
          "--enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,WebRtcAllowH265Receive,Vulkan,VaapiIgnoreDriverChecks,DefaultANGLEVulkan,VulkanFromANGLE"
          "--force-fieldtrials=WebRTC-Video-H26xPacketBuffer/Enabled"
        ];
      })
    ];

    programs.firefox = {
      package = pkgs.firefox-beta;
      enable = true;
    };
  };
}
