#!/usr/bin/env bash
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# set-bootnext.sh - point an FMO target at its network boot entry for exactly one
# boot, so `ghaf-netboot` can install without anyone holding down F12.
#
# BootNext (-n), never BootOrder (-o). BootNext is one-shot and self-clearing, so
# a netboot that fails falls back to the disk on the next boot. Rewriting
# BootOrder on a machine you can only reach over the network is how you end up
# with one stuck in firmware and a trip to wherever it lives.
#
# The device side of this is upstream and arrives with the ghaf input:
#   ghaf:modules/hardware/x86_64-generic/x86_64-linux.nix  puts efibootmgr on PATH
#   ghaf:modules/development/dt-host.nix                   NOPASSWD for efibootmgr
#                                                          and `systemctl reboot`
# Both are gated on the debug tooling and x86_64, so a release image would have
# neither and this script would correctly report that it cannot set BootNext.
#
# Ported from the netboot preflight in ghaf .github/skills/ghaf-hw-test/ghaf-hw-test
# @ 2b01173b, which is not otherwise carried into this repo.
#
# Exit status: 0 BootNext set (or dry run fine), 1 could not, 2 usage error.

set -uo pipefail

MACHINE=""
HOST_IP=""
ENTRY=""
DRY_RUN=0
DO_REBOOT=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FMO_CONFIG_TOOL="$REPO_ROOT/.claude/scripts/fmo-config.py"

# ghaf-host holds the firmware's efivarfs; net-vm does not. Everything here has
# to run one hop in, at the fixed internal address.
HOST_VM_IP=192.168.100.2

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Set a one-shot BootNext to the target's network boot entry, so the next reboot
netboots and the one after that returns to the disk.

Options:
  -m, --machine <NAME>  Device to act on (dell-7330, lenovo-x1-gen11, ...).
                        Reads host_ip, ssh_identity and netboot_boot_entry.
  -i, --ip <ADDRESS>    Device address (overrides the config)
  -e, --entry <XXXX>    Force this boot entry number, skipping the heuristic
  -n, --dry-run         Probe and report; change nothing
  -r, --reboot          Also reboot into it. Without this the machine is left
                        armed and you reboot it yourself.
  -h, --help            This message

Exit: 0 BootNext set (or dry run fine), 1 could not, 2 usage error.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  -m | --machine)
    MACHINE="$2"
    shift 2
    ;;
  -i | --ip)
    HOST_IP="$2"
    shift 2
    ;;
  -e | --entry)
    ENTRY="$2"
    shift 2
    ;;
  -n | --dry-run)
    DRY_RUN=1
    shift
    ;;
  -r | --reboot)
    DO_REBOOT=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

info() { echo "  $*" >&2; }
warn() { echo "warning: $*" >&2; }
fail() { echo "error: $*" >&2; }

IDENTITY=""
if [ -n "$MACHINE" ]; then
  # Fail on the first lookup rather than letting all three run: an unknown
  # device name otherwise prints the same "unknown device" error three times and
  # then exits complaining about a missing address, which buries the real cause.
  if ! cfg_ip=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field host_ip); then
    exit 2
  fi
  [ -z "$HOST_IP" ] && HOST_IP="$cfg_ip"
  [ -z "$ENTRY" ] && ENTRY=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field netboot_boot_entry)
  IDENTITY=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field ssh_identity)
fi

if [ -z "$HOST_IP" ]; then
  fail "No device address. Pass --ip, or --machine with host_ip set in .claude/config.local.yaml."
  exit 2
fi

# A private control socket, and this is a correctness requirement rather than a
# speed one. ghaf-host's internal address is the same 192.168.100.2 on every FMO
# device, so with a shared ControlPath - `ControlMaster auto` in ~/.ssh/config is
# common, and ghaf-build-helper encourages the aliases that go with it - ssh
# reuses whatever master already exists for that destination and never runs the
# ProxyCommand below. The --ip you passed is then silently ignored and you arm
# whichever device someone last connected to. Observed here 2026-08-02: a probe
# against 192.0.2.1 (TEST-NET-1, unroutable) reported a complete, healthy target.
CTRL_DIR="$(mktemp -d)"
trap 'rm -rf "$CTRL_DIR"' EXIT
SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes
  -o ControlMaster=auto -o "ControlPath=$CTRL_DIR/cm-%r@%h:%p" -o ControlPersist=30)
[ -n "$IDENTITY" ] && SSH_OPTS+=(-i "${IDENTITY/#\~/$HOME}")

# ProxyJump, not a hand-rolled ProxyCommand. ssh performs %h/%p/%r substitution
# on the ProxyCommand string before running it, using the OUTER destination - so
# a ControlPath of cm-%r@%h:%p inside that string resolves to ghaf-host's socket
# while the command it labels actually connects to net-vm. The outer ssh then
# finds that socket, reuses it, and every subsequent command silently runs on
# net-vm. Observed here 2026-08-02: the probe reported "EFI variables are not
# supported on this system", which is true of net-vm and says nothing about the
# machine we meant. ProxyJump lets ssh compute the jump connection's own control
# settings, so the two cannot collide.
on_host() {
  ssh "${SSH_OPTS[@]}" -o "ProxyJump=ghaf@$HOST_IP" "ghaf@$HOST_VM_IP" "$@"
}

echo "Target: ${MACHINE:-$HOST_IP} (ghaf-host via $HOST_IP)" >&2

if ! on_host true 2>/dev/null; then
  fail "Cannot reach ghaf-host through $HOST_IP."
  fail "Check the address with fmo-connect before assuming the firmware is at fault."
  # This tool needs the network, and one of the main reasons to reinstall a
  # machine is that its networking is broken - so the case it is most wanted in
  # is the one it cannot serve. Hand over to serial rather than just failing.
  fail ""
  fail "If the device is up but has no network, drive it over serial instead:"
  fail "  .claude/skills/fmo-connect/scripts/serial-run.sh -m ${MACHINE:-<machine>} \\"
  fail "    'EBM=\$(readlink -f \$(command -v efibootmgr)); sudo -n \$EBM' \\"
  fail "    'sudo -n \$(readlink -f \$(command -v efibootmgr)) -n <bootnum>' \\"
  fail "    'sudo -n \$(readlink -f \$(command -v systemctl)) reboot'"
  fail "The readlink -f is required - see the comment above about the sudo symlink."
  fail "Failing that, the firmware boot menu: F12 on the laptops, F11 on the towers."
  exit 1
fi

# Say which machine answered. Every FMO device presents ghaf-host at the same
# internal address, so the address alone does not identify what you are about to
# arm - and the operator is the only one who can tell whether it is the right one.
REACHED=$(on_host 'hostname; cat /etc/machine-id 2>/dev/null | cut -c1-8' 2>/dev/null | tr '\n' ' ' | tr -d '\r')
info "Reached: ${REACHED:-<unknown>}"

# readlink -f is load-bearing, not tidiness. `command -v efibootmgr` returns
# /run/current-system/sw/bin/efibootmgr, a symlink, while the sudoers rule in
# ghaf:modules/development/dt-host.nix names the /nix/store/...-efibootmgr-18/bin
# path it points at. sudo matches the command as written and does NOT resolve
# symlinks, so the unresolved path silently misses the NOPASSWD rule and BootNext
# falls back to a password prompt - which reads as "this image has no rule" on a
# machine that had the rule all along. The store glob is for images built before
# efibootmgr was added to PATH; it is in the closure there either way, because
# canTouchEfiVariables pulls it in for the bootloader installer.
# shellcheck disable=SC2016  # $p and the globs must expand on the target, not here
EBM=$(on_host 'p=$(command -v efibootmgr || ls /nix/store/*-efibootmgr-*/bin/efibootmgr 2>/dev/null | head -1); [ -n "$p" ] && readlink -f "$p"' 2>/dev/null | tr -d '\r')
if [ -z "$EBM" ]; then
  fail "efibootmgr not found on ghaf-host - cannot inspect or set boot entries."
  fail "A release image has neither efibootmgr nor the NOPASSWD rule; both are debug-only."
  exit 1
fi
info "efibootmgr: $EBM"

# SecureBoot is a 5-byte efivar: 4 attribute bytes then the value. Worth checking
# here rather than letting the target reject the chain silently at boot.
SB=$(on_host "od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk '{print \$5}'" 2>/dev/null | tr -d ' \r')
if [ "$SB" = "1" ]; then
  fail "Secure Boot is ENABLED - the netboot chain is unsigned and will be rejected."
  exit 1
elif [ -z "$SB" ]; then
  warn "Could not read the SecureBoot efivar; proceeding, but the target may refuse the chain."
else
  info "Secure Boot is off"
fi

# Keep efibootmgr's own stderr and ssh's exit status. Folding both into an empty
# string makes a dropped connection indistinguishable from firmware that reports
# no entries, and those need opposite responses: retry the link, versus go into
# firmware setup. A flaky net-vm hop reporting "no boot entries" sent this very
# script's author looking at the wrong machine's firmware on 2026-08-02.
ENTRIES=$(on_host "$EBM -v" 2>"$CTRL_DIR/ebm.err")
EBM_RC=$?
if [ "$EBM_RC" -ne 0 ] || [ -z "$ENTRIES" ]; then
  if [ "$EBM_RC" -eq 255 ]; then
    fail "Lost the connection to ghaf-host while reading boot entries (ssh exit 255)."
    fail "This is the transport, not the firmware. Retry, or check the hop with fmo-connect."
  else
    fail "efibootmgr produced no boot entries (exit $EBM_RC)."
    fail "If efivarfs is not mounted the machine booted in legacy/CSM mode and cannot netboot."
  fi
  [ -s "$CTRL_DIR/ebm.err" ] && sed 's/^/  /' "$CTRL_DIR/ebm.err" >&2
  exit 1
fi

# Do NOT test for 'MAC(' alone. Lenovo publishes network boot as an abstract
# VenMsg entry described 'PXE BOOT', with no MAC device path anywhere, so a
# MAC-only test rejects machines that netboot perfectly well.
if [ -n "$ENTRY" ]; then
  info "Using configured entry Boot$ENTRY"
elif ! grep -qiE 'MAC\(|PXE|Network|IPv4' <<<"$ENTRIES"; then
  fail "No network boot entry found."
  fail "Enable the UEFI network stack in firmware setup, or pass --entry."
  exit 1
else
  # Which network entry, not merely whether one exists. A Dell Latitude
  # publishes three on a single MAC and all match the test above:
  #
  #   Boot0000* ONBOARD NIC (IPV4)   <- the only one that works
  #   Boot0001  ONBOARD NIC (IPV6)
  #   Boot0002  UEFI HTTPs Boot ...Uri()
  #
  # A Uri() entry is UEFI HTTP Boot: it announces DHCP option 93 architecture 16,
  # which pixiecore discards, so a BootNext to it netboots into nothing and logs
  # only "unsupported client firmware type". IPv6 is likewise not what we answer.
  CANDIDATES=$(grep -iE '^Boot[0-9A-F]{4}' <<<"$ENTRIES" |
    grep -iE 'MAC\(|PXE|Network|IPv4' |
    grep -viE 'Uri\(\)|IPv6')
  # Prefer an entry the firmware marks active (trailing * on the bootnum).
  ENTRY=$(grep -E '^Boot[0-9A-Fa-f]{4}\*' <<<"$CANDIDATES" | head -1 |
    sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/')
  [ -z "$ENTRY" ] && ENTRY=$(head -1 <<<"$CANDIDATES" |
    sed -E 's/^Boot([0-9A-Fa-f]{4}).*/\1/')
  if [ -z "$ENTRY" ]; then
    fail "Network boot entries exist, but none is PXE-capable."
    fail "  Only UEFI HTTP Boot (Uri()) and/or IPv6 entries were found, and the"
    fail "  server speaks PXE only. Enable PXE in firmware setup, or set"
    fail "  netboot_boot_entry in .claude/config.local.yaml to override this."
    exit 1
  fi
fi

DESC=$(grep -iE "^Boot${ENTRY}" <<<"$ENTRIES" | head -1 | sed -E 's/^Boot[0-9A-Fa-f]{4}\*?//; s/\t.*//')
info "Network boot entry: Boot$ENTRY -$DESC"

if grep -qE '^BootOrder:' <<<"$ENTRIES"; then
  FIRST=$(grep '^BootOrder:' <<<"$ENTRIES" | awk '{print $2}' | cut -d, -f1)
  if [ "${FIRST^^}" = "${ENTRY^^}" ]; then
    info "Network boot is already FIRST in BootOrder - a plain reboot will netboot"
    info "  (so will every reboot after it, while a netboot server is still running)"
  else
    info "Network boot is not first in BootOrder; that is what BootNext is for"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: would set BootNext to Boot$ENTRY. Nothing changed." >&2
  exit 0
fi

if ! on_host "sudo -n $EBM -n $ENTRY" >/dev/null 2>&1; then
  fail "Could not set BootNext."
  fail "  Most likely no NOPASSWD rule for efibootmgr on this image - it comes from"
  fail "  ghaf:modules/development/dt-host.nix and is debug-only and x86_64-only."
  fail "  Fall back to the firmware boot menu: F12 on the laptops, F11 on the towers."
  exit 1
fi
echo "BootNext set to Boot$ENTRY (one-shot, self-clearing)" >&2

if [ "$DO_REBOOT" -eq 0 ]; then
  echo "Not rebooting. Start the server first, then reboot the target:" >&2
  echo "  ssh ghaf@$HOST_IP -- ssh ghaf-host sudo systemctl reboot" >&2
  exit 0
fi

# Record the boot id first. Without it the caller cannot tell "rebooted and came
# back" from "never went down at all", and those look identical to an ssh check.
BOOT_ID_BEFORE=$(on_host "cat /proc/sys/kernel/random/boot_id" 2>/dev/null | tr -d '\r')
echo "Rebooting into netboot (boot_id before: ${BOOT_ID_BEFORE:-unknown})" >&2

# Same symlink trap as efibootmgr: the sudoers rule names the resolved
# /nix/store/...-systemd-*/bin/systemctl path, and a bare `sudo -n systemctl`
# uses the /run/current-system symlink, which does not match. Plain systemctl is
# the fallback for images without the rule, where polkit may still allow it.
# shellcheck disable=SC2016  # the command substitution must run on the target
if on_host 'sudo -n "$(readlink -f "$(command -v systemctl)")" reboot' >/dev/null 2>&1 ||
  on_host "systemctl reboot" >/dev/null 2>&1; then
  echo "Reboot issued. The target should PXE once, then return to disk boot." >&2
  exit 0
fi

warn "BootNext is set but the reboot could not be issued; power-cycle the target."
exit 1
