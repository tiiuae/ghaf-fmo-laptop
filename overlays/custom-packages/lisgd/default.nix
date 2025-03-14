# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
{ prev }:
prev.lisgd.overrideAttrs (oldAttrs: {
  postPatch =
    oldAttrs.postPatch or ""
    + ''
      cp ${./config.h} config.def.h
    '';
})
