#!/usr/bin/env bash
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# collect-logs.sh - snapshot the journals and unit state of every VM on an FMO device.
#
# One snapshot directory per run, so two runs can be diffed to separate a regression you
# introduced from noise that was always there. Unreachable VMs are recorded as such rather
# than failing the run: "docker-vm did not answer" is often the finding.
#
# Ported from ghaf .claude/skills/ghaf-logs/scripts/collect-logs.sh, with the config read
# through fmo-config.py (so the desk-local override is honoured, which upstream's inline
# reader silently drops), docker-vm extras, and the ghaf input revision in the manifest.

set -uo pipefail

HOST_IP=""
MACHINE=""
OUT=""
VMS=""
SSH_USER="${FMO_SSH_USER:-ghaf}"
PREV_BOOT=0
PASSWORD="${FMO_SSH_PASSWORD:-}"
# Fixed by ghaf:modules/common/networking/hosts.nix, which numbers net-vm first and
# ghaf-host second before any other host - that ordering is structural rather than
# configured, so this is safe to fall back to when the device cannot resolve or reach
# "ghaf-host" by name itself. Note that file is in the ghaf flake input, not this tree.
HOST_VM_IP=192.168.100.2

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FMO_CONFIG_TOOL="$REPO_ROOT/.claude/scripts/fmo-config.py"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Collect journals and unit state from an FMO device and all of its VMs.

Options:
  -m, --machine <NAME>  Read host_ip from the device config for this machine
                        (e.g. dell-7330; see: $FMO_CONFIG_TOOL --list)
  -i, --ip <ADDRESS>    Device address (overrides config)
  -o, --out <DIR>       Snapshot directory (default: fmo-logs/<timestamp>)
      --vms "a b c"     Only these VMs (default: whatever the device reports)
      --prev-boot       Also collect the previous boot (journalctl -b -1)
      --password <PW>   Password for inner hops, when the device's own user has no key
                        to the other VMs (also FMO_SSH_PASSWORD). Needs sshpass.
                        Without it those VMs are recorded UNREACHABLE.
  -h, --help            This message

Output layout:
  <DIR>/manifest.txt          what/when/where, repo and ghaf revs, deployed store paths
  <DIR>/ghaf-host/*.txt       host journal, failed units, dmesg, cmdline, microvm units
  <DIR>/docker-vm/*.txt       the above plus docker state and the fmo-* services
  <DIR>/<vm>/*.txt            per-VM journal, failed units, running system
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
  -o | --out)
    OUT="$2"
    shift 2
    ;;
  --vms)
    VMS="$2"
    shift 2
    ;;
  --password)
    PASSWORD="$2"
    shift 2
    ;;
  --prev-boot)
    PREV_BOOT=1
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

# Everything goes through fmo-config.py rather than parsing the YAML here, because the
# answer is a merge of the tracked config and the gitignored local one. Reading either
# file directly gets the wrong value for exactly the fields that are set per desk.
if [ -z "$HOST_IP" ] && [ -n "$MACHINE" ]; then
  HOST_IP=$("$FMO_CONFIG_TOOL" --device "$MACHINE" --field host_ip) || exit 1
fi

if [ -z "$HOST_IP" ]; then
  echo "No device address. Pass --ip, or --machine with host_ip set in" >&2
  echo ".claude/config.local.yaml (see .claude/config.local.yaml.example)." >&2
  exit 1
fi

[ -z "$OUT" ] && OUT="fmo-logs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

# One multiplexed connection for the whole run: every VM command tunnels through it, so a
# six-VM snapshot costs one authentication instead of ~40.
CTRL="$(mktemp -d)/cm-%r@%h:%p"
SSH_OPTS=(-o ControlMaster=auto -o "ControlPath=$CTRL" -o ControlPersist=60
  -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes)

dev_ssh() { ssh "${SSH_OPTS[@]}" "${SSH_USER}@${HOST_IP}" -- "$@"; }

# Two ways in, because the fleet is not uniformly reachable:
#
#   device  hop from the device itself (`ssh <vm>` on net-vm). One authentication for the
#           whole run and the fastest option -- but it only works where the device's own
#           user holds a key for that VM. Where it does not, inter-VM ssh wants a password,
#           which a BatchMode hop can never supply, and the symptom is every VM recorded
#           UNREACHABLE, indistinguishable from a device that failed to boot.
#   proxy   proxy-jump from here to the VM's address instead, so this machine's key (or
#           --password) does the authenticating rather than the device's.
#
# Which one works is decided per VM by probe_transports() before any collection starts.
declare -A VM_VIA
declare -A VM_IP

# Multiplexed like dev_ssh, and for a sharper reason than speed: collect_one issues about
# six commands per VM and the VMs run in parallel, so an unmultiplexed proxy opens dozens of
# concurrent sessions through net-vm. Its sshd refuses them ("Connection timed out during
# banner exchange") and individual files land holding that error instead of log data --
# a partial snapshot that still looks successful. probe_transports connects once per VM
# first, so the masters exist before the parallel phase starts.
proxy_ssh() {
  local ip="$1"
  shift
  if [ -n "$PASSWORD" ]; then
    sshpass -p "$PASSWORD" ssh -o ControlMaster=auto -o "ControlPath=$CTRL" \
      -o ControlPersist=60 -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
      -o PreferredAuthentications=password \
      -o "ProxyJump=${SSH_USER}@${HOST_IP}" "${SSH_USER}@${ip}" -- "$@"
  else
    ssh "${SSH_OPTS[@]}" -o "ProxyJump=${SSH_USER}@${HOST_IP}" "${SSH_USER}@${ip}" -- "$@"
  fi
}

hop_ssh() {
  local vm="$1"
  shift
  dev_ssh ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$vm" "$@"
}

vm_ssh() {
  local vm="$1"
  shift
  case "${VM_VIA[$vm]:-hop}" in
  proxy) proxy_ssh "${VM_IP[$vm]}" "$@" ;;
  *) hop_ssh "$vm" "$@" ;;
  esac
}

# Serial, and deliberately before the parallel collection: the chosen transport has to be
# in the parent shell for the forked collectors to inherit it.
probe_transports() {
  local vm
  for vm in "$@"; do
    if hop_ssh "$vm" true 2>/dev/null; then
      VM_VIA[$vm]=hop
    elif [ -n "${VM_IP[$vm]:-}" ] && proxy_ssh "${VM_IP[$vm]}" true 2>/dev/null; then
      VM_VIA[$vm]=proxy
    else
      VM_VIA[$vm]=none
    fi
  done
}

if [ -n "$PASSWORD" ] && ! command -v sshpass >/dev/null 2>&1; then
  echo "--password given but sshpass is not on PATH; try: nix-shell -p sshpass" >&2
  exit 1
fi

echo "Connecting to ${SSH_USER}@${HOST_IP} ..." >&2
if ! dev_ssh true 2>/dev/null; then
  echo "Cannot reach ${SSH_USER}@${HOST_IP}." >&2
  echo "If the device is up but unreachable, use fmo-connect's serial capture instead." >&2
  exit 1
fi

# Ask the device which VMs it has rather than assuming a fleet. A VM that should exist and
# doesn't appear here is itself a finding, so record both lists.
# Discovery has to survive the same problem collection does: if the hop to ghaf-host needs
# a password, asking the device for its own VM list fails and we would report an empty
# fleet. Settle ghaf-host's transport first, against its fixed address.
VM_IP["ghaf-host"]="$HOST_VM_IP"
probe_transports ghaf-host
if [ "${VM_VIA["ghaf-host"]}" = "none" ]; then
  echo "Cannot reach ghaf-host by hop or proxy-jump." >&2
  echo "If inter-VM ssh needs a password, pass --password (needs sshpass)." >&2
fi

HOSTS_RAW=$(vm_ssh ghaf-host cat /etc/hosts 2>/dev/null)
while read -r ip name _; do
  case "$ip" in 192.168.100.*) [ -n "$name" ] && VM_IP[$name]="$ip" ;; esac
done <<<"$HOSTS_RAW"

if [ -z "$VMS" ]; then
  UNITS=$(vm_ssh ghaf-host systemctl list-units --type=service --all --no-legend "microvm@*" 2>/dev/null |
    awk '{print $1}' | sed -n 's/^microvm@\(.*\)\.service$/\1/p' | sort -u)
  HOSTS=$(printf '%s\n' "$HOSTS_RAW" | awk '$1 ~ /^192\.168\.100\./ {print $2}' | sort -u)
  VMS=$(printf '%s\n%s\n' "$UNITS" "$HOSTS" | grep -v '^$' | grep -v '^ghaf-host$' | sort -u | tr '\n' ' ')
  printf 'microvm units:\n%s\n\n/etc/hosts entries:\n%s\n' "$UNITS" "$HOSTS" >"$OUT/vm-discovery.txt"
fi

# shellcheck disable=SC2086
probe_transports $VMS

echo "VMs: ghaf-host $VMS" >&2
for vm in ghaf-host $VMS; do
  [ "${VM_VIA[$vm]:-none}" = "none" ] || echo "  $vm via ${VM_VIA[$vm]}" >&2
done

collect_one() {
  local vm="$1"
  local dir="$OUT/$vm"
  mkdir -p "$dir"

  if [ "${VM_VIA[$vm]:-none}" = "none" ] || ! vm_ssh "$vm" true 2>/dev/null; then
    {
      echo "UNREACHABLE at $(date -Is)"
      echo "tried: hop from ${SSH_USER}@${HOST_IP}, proxy-jump to ${VM_IP[$vm]:-<no address>}"
      [ -n "$PASSWORD" ] || echo "no --password given; inter-VM ssh may require one"
    } >"$dir/UNREACHABLE.txt"
    echo "  $vm: unreachable" >&2
    return 0
  fi

  vm_ssh "$vm" journalctl -b --no-pager --no-hostname >"$dir/journal-boot.txt" 2>&1
  vm_ssh "$vm" systemctl --failed --no-legend --no-pager >"$dir/failed-units.txt" 2>&1
  vm_ssh "$vm" readlink /run/current-system >"$dir/current-system.txt" 2>&1
  vm_ssh "$vm" systemctl list-units --state=failed,activating --no-legend --no-pager \
    >"$dir/units-not-running.txt" 2>&1

  if [ "$PREV_BOOT" -eq 1 ]; then
    vm_ssh "$vm" journalctl -b -1 --no-pager --no-hostname >"$dir/journal-prevboot.txt" 2>&1
  fi

  if [ "$vm" = "ghaf-host" ]; then
    vm_ssh "$vm" dmesg >"$dir/dmesg.txt" 2>&1
    vm_ssh "$vm" cat /proc/cmdline >"$dir/cmdline.txt" 2>&1
    vm_ssh "$vm" systemctl list-units "microvm@*" --all --no-legend --no-pager \
      >"$dir/microvm-units.txt" 2>&1
    vm_ssh "$vm" cat /etc/hosts >"$dir/hosts.txt" 2>&1
    # The NATS client certificates are minted here and shared into the guests. When they
    # are missing in net-vm or docker-vm this is where the cause is, so collect the
    # generator's state next to the guests that consume it.
    vm_ssh "$vm" systemctl status --no-pager openssl-certs-gen.service \
      >"$dir/certs-gen.txt" 2>&1
  fi

  # The FMO payload lives in docker-vm and none of it shows up in a generic journal
  # collection: the containers are Docker's, not systemd's, and the interesting state is
  # on a virtiofs share and a size-capped guestStorage volume.
  if [ "$vm" = "docker-vm" ]; then
    vm_ssh "$vm" sudo docker ps -a >"$dir/docker-ps.txt" 2>&1
    vm_ssh "$vm" journalctl -b -u docker --no-pager --no-hostname \
      >"$dir/journal-docker.txt" 2>&1
    vm_ssh "$vm" systemctl status --no-pager \
      fmo-dci.service setup-onboarding-agent.service \
      fmo-update-kernel-hostname.service \
      >"$dir/fmo-services.txt" 2>&1
    vm_ssh "$vm" ls -la /var/lib/fogdata >"$dir/fogdata.txt" 2>&1
    # guestStorage is capped in modules/microvm/docker/config.nix, so a full disk is a real
    # failure mode here and one that presents as containers refusing to start.
    vm_ssh "$vm" df -h / /var/lib/docker /var/lib/fogdata >"$dir/disk.txt" 2>&1
  fi

  echo "  $vm: $(wc -l <"$dir/journal-boot.txt") journal lines" >&2
}

# Collect in parallel — the connection is already multiplexed, and a full fleet snapshot
# serially takes long enough that people skip taking one.
for vm in ghaf-host $VMS; do
  collect_one "$vm" &
done
wait

{
  echo "collected_at: $(date -Is)"
  echo "host_ip: $HOST_IP"
  echo "machine: ${MACHINE:-unspecified}"
  echo "vms: ghaf-host $VMS"
  echo "repo_rev: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "repo_dirty: $(if git diff --quiet 2>/dev/null; then echo no; else echo yes; fi)"
  # Half the answer to "what changed since this device was good" is in the input, not in
  # this tree: partitioning, the kernel, the desktop and the microVM bases are all upstream.
  # needs-reflash.sh and the fmo-log-triage agent both read this back.
  echo "ghaf_rev: $(jq -r '.nodes.ghaf.locked.rev // "unknown"' "$REPO_ROOT/flake.lock" 2>/dev/null || echo unknown)"
  echo ""
  echo "deployed systems:"
  for vm in ghaf-host $VMS; do
    if [ -f "$OUT/$vm/current-system.txt" ]; then
      echo "  $vm: $(cat "$OUT/$vm/current-system.txt")"
    else
      echo "  $vm: (unreachable)"
    fi
  done
} >"$OUT/manifest.txt"

echo "" >&2
echo "Snapshot written to $OUT" >&2
echo "Failed units across the fleet:" >&2
grep -l . "$OUT"/*/failed-units.txt 2>/dev/null | while read -r f; do
  vm=$(basename "$(dirname "$f")")
  while read -r line; do [ -n "$line" ] && echo "  $vm: $line" >&2; done <"$f"
done
