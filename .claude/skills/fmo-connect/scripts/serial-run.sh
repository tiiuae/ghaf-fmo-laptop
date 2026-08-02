#!/usr/bin/env bash
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# serial-run.sh - log in over the serial console and run commands non-interactively.
#
# serial-console.sh captures what a device says. This drives it: it logs in and
# runs a command list, which is what you need when the device is up but has no
# network - a failed net-vm, a bad firewall rule, a NIC that was never passed
# through. In exactly those cases every ssh-based tool here is useless, and that
# is exactly when you most need to look inside.
#
# It is deliberately dumb: fixed sleeps, no prompt detection, no exit status from
# the target. A serial console gives you a byte stream, not a session, and
# pretending otherwise produces a tool that fails in ways nobody can debug. Treat
# the output as evidence to read, not as something to branch on. If a command
# needs longer than its slot, raise FMO_SERIAL_STEP.
#
# Credentials default to the debug image's initial account (ghaf/ghaf, from
# ghaf.users.admin + initialPassword). A release image will not accept them.
#
# Usage:
#   serial-run.sh -m dell-7330 'systemctl --failed' 'ip -br addr'
#   serial-run.sh -d /dev/ttyUSB0 -f commands.txt
#   echo 'journalctl -b -p err | tail -40' | serial-run.sh -m dell-7330 -

set -uo pipefail

DEVICE=""
BAUD=""
MACHINE=""
CMDFILE=""
USER_NAME="${FMO_SERIAL_USER:-ghaf}"
PASSWORD="${FMO_SERIAL_PASSWORD:-ghaf}"
STEP="${FMO_SERIAL_STEP:-3}"
RAW_LOG=""

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FMO_CONFIG_TOOL="$REPO_ROOT/.claude/scripts/fmo-config.py"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <command> [command ...]
       $(basename "$0") [options] -f <file>
       $(basename "$0") [options] -          # read commands from stdin

Log in over the serial console and run commands, capturing the output.

Options:
  -m, --machine <NAME>  Read serial_device/serial_baud from the device config
  -d, --device <PATH>   Serial device node, e.g. /dev/ttyUSB0
  -b, --baud <RATE>     Baud rate (default: from config, else 115200)
  -f, --file <FILE>     Read commands from FILE, one per line
  -s, --step <SECS>     Seconds to wait after each command (default: $STEP,
                        env FMO_SERIAL_STEP). Raise it for slow commands.
      --raw-log <FILE>  Also keep the unfiltered capture, escape codes and all
  -h, --help            This message

Environment:
  FMO_SERIAL_USER / FMO_SERIAL_PASSWORD   default ghaf / ghaf (debug images)

Exit: 0 if the session ran, 1 on setup failure, 2 usage error. The target's own
exit statuses are NOT propagated - add 'echo rc=\$?' to a command if you need one.
EOF
}

CMDS=()
while [ $# -gt 0 ]; do
  case "$1" in
  -m | --machine) MACHINE="$2"; shift 2 ;;
  -d | --device) DEVICE="$2"; shift 2 ;;
  -b | --baud) BAUD="$2"; shift 2 ;;
  -f | --file) CMDFILE="$2"; shift 2 ;;
  -s | --step) STEP="$2"; shift 2 ;;
  --raw-log) RAW_LOG="$2"; shift 2 ;;
  -h | --help) usage; exit 0 ;;
  -) CMDFILE="/dev/stdin"; shift ;;
  -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  *) CMDS+=("$1"); shift ;;
  esac
done

if [ -n "$CMDFILE" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && CMDS+=("$line")
  done <"$CMDFILE"
fi

if [ ${#CMDS[@]} -eq 0 ]; then
  echo "error: no commands given" >&2
  usage >&2
  exit 2
fi

# Same config path as serial-console.sh, so the two agree about which port a
# machine is on.
if [ -n "$MACHINE" ]; then
  if [ ! -x "$FMO_CONFIG_TOOL" ]; then
    echo "error: config reader not found: $FMO_CONFIG_TOOL" >&2
    exit 1
  fi
  cfg_dev=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field serial_device) || exit 1
  cfg_baud=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field serial_baud) || exit 1
  [ -z "$DEVICE" ] && DEVICE="$cfg_dev"
  [ -z "$BAUD" ] && BAUD="$cfg_baud"
fi
[ -z "$BAUD" ] && BAUD=115200

if [ -z "$DEVICE" ]; then
  echo "error: no serial device given and none configured." >&2
  echo "Candidates currently present:" >&2
  ls -1 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null >&2 || echo "  (none - is the cable attached?)" >&2
  exit 1
fi
if [ ! -c "$DEVICE" ]; then
  echo "error: not a character device: $DEVICE" >&2
  exit 1
fi

# A serial port is exclusive; competing with a stale picocom loses half the output.
if command -v fuser >/dev/null 2>&1 && fuser "$DEVICE" >/dev/null 2>&1; then
  echo "warning: another process already holds $DEVICE; output may be interleaved" >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CAP="${RAW_LOG:-$WORK/raw.log}"

stty -F "$DEVICE" "$BAUD" raw -echo || {
  echo "error: could not configure $DEVICE at $BAUD" >&2
  exit 1
}

cat "$DEVICE" >"$CAP" 2>/dev/null &
CATPID=$!
trap 'kill "$CATPID" 2>/dev/null; wait "$CATPID" 2>/dev/null; rm -rf "$WORK"' EXIT

send() { printf '%s\r' "$1" >"$DEVICE"; sleep "${2:-$STEP}"; }

echo "Driving $DEVICE at $BAUD baud as $USER_NAME" >&2

# Wake the console. If a shell is already open the login lines echo harmlessly;
# if a login prompt is waiting, they log in. Doing both unconditionally is what
# keeps this working without prompt detection.
send "" 1
send "" 1
send "$USER_NAME" 2
send "$PASSWORD" 4

# Escape codes and a pager would make the capture unreadable.
send "export TERM=dumb SYSTEMD_COLORS=0 PAGER=cat" 2

for c in "${CMDS[@]}"; do
  send "echo ===FMO-CMD=== $c" 1
  send "$c" "$STEP"
done
send "echo ===FMO-END===" 2

sleep 1
kill "$CATPID" 2>/dev/null
wait "$CATPID" 2>/dev/null

# Strip CR, OSC title sequences and CSI colour codes; the target echoes our own
# input back, so the ===FMO-CMD=== markers are what make the output readable.
sed 's/\r$//' "$CAP" |
  sed -E 's/\x1b\][0-9]*;[^\x07]*\x07//g; s/\x1b\[[0-9;?]*[a-zA-Z]//g' |
  sed -n '/===FMO-CMD===/,/===FMO-END===/p'

[ -n "$RAW_LOG" ] && echo "raw capture: $RAW_LOG" >&2
exit 0
