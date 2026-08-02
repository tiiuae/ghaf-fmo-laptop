---
name: fmo-connect
description: Get a shell or console on an FMO device or one of its VMs - over ethernet when it is up, over serial when it is not. Use this whenever a device is unreachable, unresponsive, stuck at boot, hung after an install, or when you need to run a command on ghaf-host or a named VM (gui-vm, net-vm, admin-vm, audio-vm, docker-vm). Also use it when the user says the device "won't come up", "isn't responding", "is bricked", or asks to check whether it is alive. This is the FMO counterpart of ghaf's ghaf-connect skill; use it when someone asks for "ghaf-connect" in this repo.
---

# Reaching an FMO device

Two transports, and the choice is not a preference — it is a diagnosis. Ethernet means the
device booted far enough to bring up net-vm and sshd. Serial is what you have when it
didn't. Read `fmo-target` first for the address map and config location.

## Decide which transport you need

Try ethernet first; it is faster and gives you every VM. Escalate to serial when ethernet
fails, because *how* it fails is itself evidence:

| Symptom | What it suggests | Next step |
|---|---|---|
| ssh connects, VMs reachable | device is healthy | carry on over ethernet |
| ssh refused / no route | net-vm down, or NIC not passed through | serial; check host boot and `microvm@net-vm.service` |
| ssh times out, no link on `usb_iface` | device off, wedged, or not enumerated | serial; check power and cable |
| ssh works but a VM name won't resolve | that microVM failed to start | ethernet is fine — go straight to `fmo-logs` on ghaf-host |
| ssh works, desktop fine, but onboarding or containers are dead | docker-vm is up, its services are not | ethernet is fine — `fmo-logs`, then read `docker-vm/fmo-services.txt` and `docker-ps.txt` |

That last row is the FMO-specific one, and it is worth stating because the device looks
entirely healthy from the outside: the desktop logs in, ssh works, and the thing the machine
actually exists to do is not running.

## Over ethernet

The device's external address belongs to net-vm; everything else is one hop in.

```bash
ping -c2 <host_ip>
ssh -o ConnectTimeout=5 ghaf@<host_ip> -- true && echo reachable
ssh ghaf@<host_ip> -- ssh ghaf-host  systemctl --failed
ssh ghaf@<host_ip> -- ssh gui-vm     journalctl -b -u greetd --no-pager
ssh ghaf@<host_ip> -- ssh docker-vm  systemctl --failed
```

If the link itself is suspect, check the host side before blaming the device — the interface
facing it is `usb_iface` in the config, usually `ghaf-usb`:

```bash
ip -br link show ghaf-usb
ip -br addr show ghaf-usb
```

A USB-ethernet adapter that renumbered or a cable in the wrong port accounts for a good
share of "the device is dead" reports, and costs seconds to rule out.

## Over serial

Use `scripts/serial-console.sh`. It reads `serial_device` and `serial_baud` through
`fmo-config.py` (so the desk-local override is honoured), warns when another process already
holds the port, and has a non-interactive capture mode:

```bash
# Capture boot output — do this BEFORE power-cycling, so you catch the failure itself
.claude/skills/fmo-connect/scripts/serial-console.sh -m dell-7330 -c 180

# Interactive session
.claude/skills/fmo-connect/scripts/serial-console.sh -d /dev/ttyUSB0 -b 115200
```

Prefer `--capture` when you are gathering evidence rather than driving the device. It needs
only coreutils, produces a log file you can hand to `fmo-log-triage`, and does not require a
terminal you can type into.

### Running commands over serial

`serial-console.sh` captures what the device says. `serial-run.sh` **drives** it — logs in and
runs a command list — which is what you need when the device is up but has no network:

```bash
.claude/skills/fmo-connect/scripts/serial-run.sh -m dell-7330 \
  'systemctl --failed' 'ip -br addr' 'journalctl -b -u microvm@net-vm.service | tail -30'
```

This is the only way in when net-vm is down, and that is not a rare case — a failed NIC
passthrough, a bad firewall rule or a crash-looping net-vm all leave a perfectly healthy
machine that no ssh-based tool in this repo can reach. `fmo-logs`, `fmo-deploy` and
`set-bootnext.sh` all go over ssh and are useless in exactly that situation.

It logs in with the debug image's initial account (`ghaf`/`ghaf`; override with
`FMO_SERIAL_USER` / `FMO_SERIAL_PASSWORD`), and a release image will refuse them.

Two limits worth knowing before you trust the output. It uses **fixed sleeps, not prompt
detection** — a command slower than its slot gets truncated, so raise `-s`/`FMO_SERIAL_STEP`
rather than concluding the command produced nothing. And **the target's exit statuses are not
propagated**; append `; echo rc=$?` when you need one. A serial console is a byte stream, not
a session, and treating it as one is how you get a tool that lies quietly.

**Serial is often genuinely absent here.** Every machine in this fleet is an x86 laptop or
tower with no debug-USB console, unlike the Jetsons upstream supports. `serial_device` is
null for every device in the shared config and is only ever set locally, from a USB-serial
adapter or — on the towers, which are the likeliest to have one — a board header. If
`serial_device` is null and no `/dev/ttyUSB*` or `/dev/ttyACM*` is present, say so plainly
rather than guessing a path; on these machines the honest answer is often that there is no
console to attach to and the next move is a reinstall over netboot.

## Sequencing a rescue

When a device is unresponsive after an install or deploy, the order matters — the evidence
you want is destroyed by the fix:

1. Attach serial and start `--capture` **first**.
2. Power-cycle only then, so the capture contains the whole boot.
3. Read the capture for the earliest failure, not the loudest one.
4. Once networking returns, switch to `fmo-logs` for the full picture across VMs; serial only
   ever shows you the host console.

If the capture is empty, that is informative too: no output at all usually means wrong baud,
wrong node, or a device with no power — not a kernel that died silently.

<!-- Ported from ghaf .claude/skills/ghaf-connect/SKILL.md @ 2b01173b. Divergences: docker-vm symptom
     row, fmo-config.py as the config reader, serial-availability paragraph rewritten for a fleet with
     no debug-USB console. -->
