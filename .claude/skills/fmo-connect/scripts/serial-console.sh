#!/usr/bin/env bash
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# serial-console.sh - attach to an FMO device's serial console, or capture from it
# non-interactively.
#
# Capture mode exists because the interesting case is a device that never reaches the
# network: a kernel panic, a failed initrd, a bootloader that hangs. Serial is the only
# evidence there, and an agent cannot drive an interactive terminal.
#
# Expect to find nothing to attach to more often than not. Every machine in this fleet is
# an x86 laptop or tower with no debug-USB console, unlike the Jetsons upstream supports,
# so serial_device is null for every device in the tracked config and is only ever set in
# config.local.yaml - from a USB-serial adapter, or a board header on the towers. "There is
# no console here" is a legitimate answer; do not guess a node to produce one.
#
# Ported from ghaf .claude/skills/ghaf-connect/scripts/serial-console.sh, with the config
# read through fmo-config.py so the desk-local override is actually honoured.

set -euo pipefail

DEVICE=""
BAUD=""
LOG=""
CAPTURE=""
MACHINE=""

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FMO_CONFIG_TOOL="$REPO_ROOT/.claude/scripts/fmo-config.py"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Attach to a serial console, or capture from it for a fixed time.

Options:
  -m, --machine <NAME>   Read serial_device/serial_baud from the device config for this
                         machine (dell-7330, lenovo-x1-gen11, tower-5080, ...).
                         Explicit flags win.
                         See: .claude/scripts/fmo-config.py --list
  -d, --device <PATH>    Serial device node, e.g. /dev/ttyUSB0
  -b, --baud <RATE>      Baud rate (default: 115200)
  -c, --capture <SECS>   Capture for SECS seconds and exit, instead of attaching.
                         Use this when you need evidence, not a session.
  -l, --log <FILE>       Write output here (default: a timestamped file in \$PWD)
  -h, --help             This message

Examples:
  $(basename "$0") -m dell-7330 -c 120      # capture two minutes of boot output
  $(basename "$0") -d /dev/ttyUSB0          # interactive session, logged
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  -m | --machine)
    MACHINE="$2"
    shift 2
    ;;
  -d | --device)
    DEVICE="$2"
    shift 2
    ;;
  -b | --baud)
    BAUD="$2"
    shift 2
    ;;
  -c | --capture)
    CAPTURE="$2"
    shift 2
    ;;
  -l | --log)
    LOG="$2"
    shift 2
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

# Pull defaults from the device config so serial settings live in one place. Go through
# fmo-config.py rather than parsing the YAML here: serial_device is a desk-local field, so
# reading the tracked file directly returns null for exactly the value that matters.
if [ -n "$MACHINE" ]; then
  if [ ! -x "$FMO_CONFIG_TOOL" ]; then
    echo "Config reader not found: $FMO_CONFIG_TOOL" >&2
    echo "Run from the ghaf-fmo-laptop repo, or set FMO_CONFIG and FMO_LOCAL_CONFIG." >&2
    exit 1
  fi
  cfg_dev=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field serial_device) || exit 1
  cfg_baud=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field serial_baud) || exit 1
  [ -z "$DEVICE" ] && DEVICE="$cfg_dev"
  [ -z "$BAUD" ] && BAUD="$cfg_baud"
fi

[ -z "$BAUD" ] && BAUD=115200

if [ -z "$DEVICE" ]; then
  echo "No serial device given and none configured." >&2
  echo "Candidates currently present:" >&2
  ls -1 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null >&2 || echo "  (none — is the cable attached?)" >&2
  exit 1
fi

if [ ! -c "$DEVICE" ]; then
  echo "Not a character device: $DEVICE" >&2
  echo "Candidates currently present:" >&2
  ls -1 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null >&2 || echo "  (none — is the cable attached?)" >&2
  exit 1
fi

# A serial port is exclusive. Silently competing with a stale picocom is a classic way to
# lose half the boot log, so say so plainly instead.
if command -v fuser >/dev/null 2>&1 && fuser "$DEVICE" >/dev/null 2>&1; then
  echo "Warning: another process already holds $DEVICE:" >&2
  fuser -v "$DEVICE" >&2 || true
  echo "Output may be interleaved or lost. Close it first if you can." >&2
fi

if [ -z "$LOG" ]; then
  LOG="serial-$(basename "$DEVICE")-$(date +%Y%m%d-%H%M%S).log"
fi

if [ -n "$CAPTURE" ]; then
  echo "Capturing ${CAPTURE}s from $DEVICE at ${BAUD} baud -> $LOG" >&2
  stty -F "$DEVICE" "$BAUD" raw -echo
  # Exit status 124 from timeout just means the window elapsed, which is the normal
  # outcome here — only a genuine read error should fail the script.
  set +e
  timeout "$CAPTURE" cat "$DEVICE" | tee "$LOG"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ]; then
    echo "Read from $DEVICE failed (exit $rc)" >&2
    exit "$rc"
  fi
  echo "Captured $(wc -l <"$LOG") lines to $LOG" >&2
  exit 0
fi

echo "Attaching to $DEVICE at ${BAUD} baud, logging to $LOG" >&2
if command -v picocom >/dev/null 2>&1; then
  echo "Exit with Ctrl-A Ctrl-X" >&2
  exec picocom --baud "$BAUD" --logfile "$LOG" "$DEVICE"
elif command -v tio >/dev/null 2>&1; then
  echo "Exit with Ctrl-T q" >&2
  exec tio --baudrate "$BAUD" --log --log-file "$LOG" "$DEVICE"
else
  echo "Neither picocom nor tio found. Either:" >&2
  echo "  nix-shell -p picocom --run '$(basename "$0") -d $DEVICE -b $BAUD'" >&2
  echo "  or use --capture <secs>, which needs only coreutils." >&2
  exit 1
fi
