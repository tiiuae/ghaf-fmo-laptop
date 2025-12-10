# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ prev }:
prev.cosmic-panel.overrideAttrs (oldAttrs: {
  patches = oldAttrs.patches ++ [
    ./0001-Fix-touchscreen-click-events-for-panel-applets.patch
  ];
})
