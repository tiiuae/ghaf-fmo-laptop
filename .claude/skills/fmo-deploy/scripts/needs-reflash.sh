#!/usr/bin/env bash
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# needs-reflash.sh - decide whether a change can go out with `just rebuild`, or needs a
# full reinstall.
#
# `nixos-rebuild switch` replaces the running system generation. It cannot repartition a
# disk, rewrite a bootloader, or change what the firmware loads. When a change touches
# those, switching appears to succeed and leaves the device in a state that does not match
# the image you built — which is worse than an obvious failure, because you then debug the
# wrong system.
#
# Exit status: 0 = rebuild is enough, 1 = reinstall needed, 2 = usage error.
#
# Ported from ghaf .claude/skills/ghaf-deploy/scripts/needs-reflash.sh. The path patterns
# are entirely rewritten: upstream's match modules/partitioning/, lib/builders/ and
# modules/microvm/sysvms/, none of which exist in this tree - they are in the ghaf input.
# Which is also why the flake.lock check below has no upstream counterpart.

set -uo pipefail

BASELINE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [baseline-ref]

Classify the pending changes as rebuild-safe or reflash-required.

  baseline-ref   What the device is currently running, e.g. the repo_rev from a log
                 snapshot manifest. Defaults to uncommitted changes only.

Exit: 0 rebuild is enough, 1 reflash needed, 2 usage error.
EOF
}

case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
"") BASELINE="" ;;
*) BASELINE="$1" ;;
esac

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 2
fi

if [ -n "$BASELINE" ]; then
  if ! git rev-parse --verify --quiet "$BASELINE" >/dev/null; then
    echo "Unknown baseline ref: $BASELINE" >&2
    exit 2
  fi
  CHANGED=$(
    git diff --name-only "$BASELINE"...HEAD
    git diff --name-only HEAD
    git diff --name-only --cached
  )
else
  CHANGED=$(
    git diff --name-only HEAD
    git diff --name-only --cached
  )
fi

CHANGED=$(printf '%s\n' "$CHANGED" | grep -v '^$' | sort -u)

if [ -z "$CHANGED" ]; then
  echo "No changes against ${BASELINE:-the working tree}. Nothing to deploy."
  exit 0
fi

# Each pattern is something `switch` provably cannot apply to a running system.
declare -a REASONS=()
check() {
  local pattern="$1" why="$2" hits
  hits=$(printf '%s\n' "$CHANGED" | grep -E "$pattern" || true)
  if [ -n "$hits" ]; then
    REASONS+=("$why")
    while read -r f; do [ -n "$f" ] && REASONS+=("    $f"); done <<<"$hits"
  fi
}

check '^targets/' \
  "Target or installer definition — image composition, applied at build time."
check '^modules/hardware/' \
  "Hardware definition — PCI and USB passthrough and per-VM memory/vcpu take effect at boot."
check '^modules/microvm/(host|netvm|guivm)\.nix' \
  "System-VM topology or virtiofs shares — switch does not re-provision a running microVM."
check '^modules/microvm/docker/' \
  "docker-VM definition or storage sizing — guestStorage is sized when the volume is created."
check '^modules/profile/fmo\.nix' \
  "Profile — partitioning, storage encryption, passthrough mode and the VM set all live here."
check 'kernel' \
  "Kernel or kernel config — a new kernel needs a boot, and cmdline changes need the bootloader."

# Deliberately NOT listed, because they are the common case here and treating them as
# reinstalls would make this tool useless: modules/fmo/ (the services), packages/,
# overlays/, nix/, the justfile and the docs. Those all switch cleanly — though a service
# change still needs `systemctl restart microvm@<vm>.service` to take effect, which is a
# different problem and is covered in the fmo-deploy skill.

# Path patterns miss a kernel command line edited inside a file that otherwise looks
# harmless, so look at the content of the change too. The cmdline is baked into the boot
# entry: switching leaves the running kernel with the old parameters.
if [ -n "$BASELINE" ]; then
  DIFF_BODY=$(
    git diff -U0 "$BASELINE"...HEAD -- '*.nix' 2>/dev/null
    git diff -U0 HEAD -- '*.nix' 2>/dev/null
  )
else
  DIFF_BODY=$(
    git diff -U0 HEAD -- '*.nix' 2>/dev/null
    git diff -U0 --cached -- '*.nix' 2>/dev/null
  )
fi
CMDLINE_HITS=$(printf '%s\n' "$DIFF_BODY" |
  grep -E '^[+-][^+-]*(kernelParams|module_blacklist|stage1\.kernelModules|bootloader|disko|partitioning|storage\.encryption|maximumSize|hardware\.passthrough|microvm\.shares|vmConfig)' || true)
if [ -n "$CMDLINE_HITS" ]; then
  REASONS+=("Kernel command line or boot/disk/VM-sizing configuration edited in place:")
  while read -r l; do [ -n "$l" ] && REASONS+=("    ${l:0:100}"); done <<<"$CMDLINE_HITS"
fi

# No upstream counterpart, and the most important check in this file. Partitioning, the
# bootloader, the kernel and the microVM bases all live in the ghaf input, i.e. in the
# store rather than in this tree, so a moved lock node can carry any of them and none of
# the path patterns above can see it. Saying "cannot classify" is the honest answer;
# staying silent would imply the bump is inert, which is the exact failure this tool exists
# to prevent.
if printf '%s\n' "$CHANGED" | grep -qx 'flake\.lock'; then
  old_rev=""
  new_rev=""
  if [ -n "$BASELINE" ]; then
    old_rev=$(git show "${BASELINE}:flake.lock" 2>/dev/null |
      jq -r '.nodes.ghaf.locked.rev // ""' 2>/dev/null || echo "")
  else
    old_rev=$(git show "HEAD:flake.lock" 2>/dev/null |
      jq -r '.nodes.ghaf.locked.rev // ""' 2>/dev/null || echo "")
  fi
  new_rev=$(jq -r '.nodes.ghaf.locked.rev // ""' flake.lock 2>/dev/null || echo "")
  if [ -n "$new_rev" ] && [ "$old_rev" != "$new_rev" ]; then
    REASONS+=("ghaf input moved ${old_rev:0:12} -> ${new_rev:0:12}; this cannot be classified here.")
    REASONS+=("    Upstream modules are not in this tree. Read ghaf's log between those two")
    REASONS+=("    revisions for partitioning, boot, hardware, kernel or microvm/ changes.")
  fi
fi

echo "Changed since ${BASELINE:-working tree}:"
printf '%s\n' "$CHANGED" | sed 's/^/  /'
echo ""

if [ ${#REASONS[@]} -eq 0 ]; then
  cat <<EOF
Verdict: REBUILD is enough.

  just rebuild <netvm-ip> .#fmo-<machine>-debug boot

Nothing here changes partitioning, boot, hardware or VM topology. Restart the affected
microVM afterwards so it picks up the new configuration:

  ssh ghaf@<host_ip> -- ssh ghaf-host sudo systemctl restart microvm@<vm>.service
EOF
  exit 0
fi

echo "Verdict: REINSTALL required."
echo ""
for r in "${REASONS[@]}"; do echo "  $r"; done
cat <<EOF

A switch would appear to succeed and leave the device not matching the image. Reinstall
instead — either the ISO (just build .#fmo-<machine>-debug-installer "") or netboot
(just build-netboot, then ghaf-netboot). See the fmo-deploy skill for both paths.

If you are certain a particular finding above is inert for your change, say so explicitly
rather than silently switching — the failure mode is a device that disagrees with your
source tree.
EOF
exit 1
