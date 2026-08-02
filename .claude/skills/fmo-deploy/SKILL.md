---
name: fmo-deploy
description: Get a built FMO change onto a device - by nixos-rebuild when that is sufficient, by writing an installer ISO to a USB stick when it is not, or by netboot/PXE when you want the same install without media - then reboot, wait for it to come back, and confirm what is actually running. Use whenever asked to deploy, flash, install, reinstall, update or push a change to an FMO laptop or tower, to netboot or PXE boot a machine, or after building an image that needs to go on hardware. Also use when deciding whether a change can be switched or needs a reinstall. This is the FMO counterpart of ghaf's ghaf-deploy skill; use it when someone asks for "ghaf-deploy" in this repo.
---

# Deploying to an FMO device

Three paths. The first two are the usual choice, and choosing wrong is expensive in opposite
directions: reinstalling when a switch would do wastes half an hour per iteration, while
switching when a reinstall was needed leaves a device that quietly disagrees with your source
tree. The third, netboot, delivers the same install as the second without USB media — worth
it when reinstalling repeatedly or when the machine is not on your desk.

Read `fmo-target` for addresses and target names. Installing is destructive — see the safety
section before running it unattended.

## Decide which path

```bash
.claude/skills/fmo-deploy/scripts/needs-reflash.sh                 # uncommitted changes
.claude/skills/fmo-deploy/scripts/needs-reflash.sh <deployed-rev>  # vs what is on the device
```

The baseline ref is the `repo_rev` recorded in an `fmo-logs` snapshot manifest, so the
question it answers is precisely "can what I changed since that device was last deployed go
out with a switch?". Exit status is 0 for rebuild, 1 for reinstall, so a loop can branch on it.

It reports reinstall for target definitions, hardware definitions, microVM topology, the
docker-VM's storage sizing, and the profile — the things `nixos-rebuild switch` provably
cannot apply to a running system.

**It cannot classify a `flake.lock` bump, and says so rather than staying silent.**
Partitioning, the bootloader, the kernel and the microVM bases all live in the `ghaf` input,
so a moved lock node can carry any of them and the evidence is not in this tree. When it
reports one, read ghaf's log between the two revisions before deciding.

## Path 1: rebuild (minutes)

`just rebuild` wraps `ghaf-build-helper`, which wraps `nixos-rebuild` with the ssh topology
already set up and the netrc installed for the sandbox. Note the positional form — the first
argument is the **net-vm it proxy-jumps through**, and it targets `root@ghaf-host`:

```bash
just rebuild <netvm-ip> .#fmo-dell-7330-debug boot
just rebuild ghaf-usb   .#fmo-dell-7330-debug switch
```

`boot` is what this fleet normally uses: activate on the next reboot rather than in place.
`switch` also works when you want the change live immediately.

**Pass an ssh_config host alias, not a bare IP, whenever one exists.** ssh matches `Host`
blocks against the name *as written on the command line*, never the resolved address, so an
IP matches only `Host *` and picks up no `IdentityFile` — it then falls back to your default
keys. Where those are FIDO2/YubiKey-backed, the jump hop demands a touch per connection or
fails outright, while the second hop (`root@ghaf-host`, an alias) quietly works, which makes
the failure look like a device problem rather than a key-selection one. Check what ssh will
actually use before blaming the device:

```bash
ssh -G root@192.168.10.135 | grep -i identityfile   # default keys — no alias matched
ssh -G ghaf-usb            | grep -i identityfile   # the key the alias specifies
```

The helper's other flags are documented by `ghaf-build-helper --help`. Do not pass
`--force-local`: `just rebuild` already passes `--option builders ''`, since a remote builder
would not have the netrc.

**A host switch does not restart the microVMs.** They keep running their old configuration
until their unit is restarted — this is the single most common way to conclude a fix didn't
work when it was simply never applied:

```bash
ssh ghaf@<host_ip> -- ssh ghaf-host sudo systemctl restart microvm@gui-vm.service
ssh ghaf@<host_ip> -- ssh ghaf-host sudo systemctl restart microvm@docker-vm.service
```

Restart only the VMs your change touched; reboot the device if you changed something
host-wide or are unsure.

**Restarting docker-VM does not reset what is inside it.** `/var/lib/docker` lives on the
VM's own guestStorage and `/persist/fogdata` is a virtiofs share owned by ghaf-host, so
images, container state, onboarding artefacts and the compose file all survive the restart —
and survive a reinstall of the host too. If you are chasing something that should have been
cleared, clear it explicitly; do not expect a restart to do it.

## Path 2: install from a USB stick (tens of minutes, destructive)

FMO does not write a raw image to the target's internal disk. It boots an installer ISO,
which carries the image, and runs the installer TUI on the machine itself:

```bash
just build .#fmo-lenovo-x1-gen11-debug-installer ""
sudo dd if=result/iso/ghaf.iso of=/dev/sdX bs=32M status=progress; sync
```

Then boot the target from the stick and, at its prompt:

```bash
sudo ghaf-installer     # pick the internal disk, confirm the erase, reboot, remove the stick
```

The ISO is always named `ghaf.iso` regardless of target. `just build-all` writes to
`result-<target>/iso/ghaf.iso` instead of `result/`.

### Before writing to a disk

There are **two** disks in play here and both are destructive: `flash_drive` (the USB stick,
on your machine) and `install_disk` (the target's internal disk, chosen in the TUI). Confirm
rather than trust:

```bash
lsblk -o NAME,SIZE,TYPE,RM,MODEL,MOUNTPOINTS /dev/sdX
.claude/scripts/fmo-config.py --device lenovo-x1-gen11 --field flash_drive
.claude/scripts/fmo-config.py --device lenovo-x1-gen11 --field install_disk
```

Check it is the size you expect, `RM` is 1 for removable media, the model matches the stick
you plugged in, and nothing on it is mounted. If the config says one device and the user says
another, stop and ask — device nodes renumber between reboots, and `/dev/sda` is a system
disk on plenty of machines.

## Path 3: netboot (tens of minutes, destructive, no USB)

The same install as Path 2, delivered over PXE. Use it when you would otherwise walk a USB
stick to the machine, or when reinstalling repeatedly: the boot artefacts carry no disk image
and are target-independent, so only the image URL changes per target and one build serves the
whole fleet.

```bash
just build .#fmo-dell-7330-debug-netboot-installer "-o result-netboot"
just build .#fmo-dell-7330-debug "-o result"
ghaf-netboot -i <iface> -m <target-mac> \
  -n result-netboot -g result --dry-run          # always start here
sudo ghaf-netboot -i <iface> -m <target-mac> \
  -n result-netboot -g result --open-firewall --exit-after-serve
```

`ghaf-netboot` is upstream's, exposed by this repo's devshell (`nix/devshell.nix`) already
wrapped in sudo — so run it from inside `nix develop`, not as a bare binary.

Preconditions, all of which fail quietly if unmet:

- **Secure Boot off** on the target — the chain is unsigned, exactly as the ISO is.
- **The target must have a network boot entry and firmware support for the NIC.** Not every
  USB-C adapter qualifies: the firmware needs its own driver for the chipset. A vendor dock
  usually works where a generic adapter emits no PXE request at all. Neither Lenovo X1 in
  this fleet has a built-in RJ45, so both need a dock. Lenovo publishes the entry as
  `PXE BOOT`, an abstract `VenMsg(...)`, **not** as a `MAC(...)` device path — so do not test
  for `MAC(` when checking whether a machine can netboot. On the Dell 7330, pick
  `ONBOARD NIC (IPV4)`: its `UEFI HTTPs Boot` entry announces a DHCP architecture the server
  discards, so the machine appears to PXE and then never gets an offer.
- **Same layer-2 network.** PXE is broadcast; it does not cross a router.
- **`-i` is the build host's interface**, not the device's. `-m` is the target's PXE NIC —
  which on a docked laptop is the dock's MAC, not the internal one. Both are in the device
  config as `netboot_iface` and `netboot_mac`.

Flags that matter more than they look:

- `--open-firewall` — without it a filtering host drops PXE **before the server sees it**.
  The server logs nothing and looks healthy while the target times out.
- `--exit-after-serve` — stops the server once the image has transferred. **On by default
  with `--install-target`**: an unattended install reboots itself when done, so if network
  boot is ahead of the disk, a server left running catches that reboot and reinstalls in a
  loop. `--no-exit-after-serve` opts out and warns. Off for interactive runs, which need it up.
- `--force-interface` — needed whenever the interface facing the target also carries the
  default route, i.e. the normal case on a shared lab network.
- `--mac` is an allowlist and is mandatory. Anything not on it gets a 404, which PXE reads as
  "ignore me". On a shared network that is the only thing stopping an unrelated machine from
  booting your installer.

`--install-target /dev/nvme0n1` makes it unattended and destructive — the same "confirm the
device" discipline as Path 2 applies, with nobody at the console. When the write finishes the
installer waits ten seconds and reboots itself into the new system; boot with
`ghaf.install_noreboot` to stay in the installer when you need to diagnose a bad install
rather than watch the evidence reboot away.

### Starting the netboot without touching the target

If the target is currently up and running FMO, you do not need someone at the keyboard
pressing F12. `set-bootnext.sh` arms a **one-shot** BootNext and optionally reboots into it:

```bash
.claude/skills/fmo-deploy/scripts/set-bootnext.sh -m dell-7330 --dry-run   # probe only
.claude/skills/fmo-deploy/scripts/set-bootnext.sh -m dell-7330             # arm, don't reboot
.claude/skills/fmo-deploy/scripts/set-bootnext.sh -m dell-7330 --reboot    # arm and reboot
```

Start the server **before** rebooting, or the target PXEs into nothing and falls through to
disk. BootNext, never BootOrder: it is one-shot and self-clearing, so a netboot that fails
leaves the machine booting normally instead of stuck in firmware at the far end of a network
you can no longer reach it over.

What it depends on, all upstream and all debug-only:
`ghaf:modules/hardware/x86_64-generic/x86_64-linux.nix` puts `efibootmgr` on PATH, and
`ghaf:modules/development/dt-host.nix` grants NOPASSWD for `efibootmgr` and
`systemctl reboot` to the `ghaf` user. A release image has neither, and the script says so
rather than appearing to work. Verified present on `fmo-dell-7330-debug`.

Two failure modes it handles that cost real time otherwise:

- **The sudo symlink trap.** `command -v efibootmgr` yields
  `/run/current-system/sw/bin/efibootmgr`, but the sudoers rule names the resolved
  `/nix/store/…-efibootmgr-18/bin/efibootmgr`. sudo matches the command *as written* and does
  not resolve symlinks, so the unresolved path misses the rule and falls back to a password
  prompt — reported as "no NOPASSWD rule on this image" on a machine that has it. The script
  resolves with `readlink -f` so the two agree.
- **Picking the wrong network entry.** A Dell Latitude publishes three on one MAC. Only
  `ONBOARD NIC (IPV4)` works: a `Uri()` entry is UEFI HTTP Boot, which announces DHCP
  architecture 16 that pixiecore discards, and IPv6 is not what the server answers. The
  script excludes both and prefers an entry the firmware marks active. Set
  `netboot_boot_entry` in `.claude/config.local.yaml` to override the heuristic.

It always prints which machine answered (`Reached: <hostname> <machine-id prefix>`). Read it.
Every FMO device presents ghaf-host at the same `192.168.100.2`, so the address you passed
does not by itself identify what you are about to arm.

**It needs the network, which is often the thing that is broken.** A machine you are
reinstalling because net-vm will not start is a machine this script cannot reach — the case
it is most wanted in is the one it cannot serve. It says so and prints the serial equivalent;
`fmo-connect`'s `serial-run.sh` is the way through, or the firmware boot menu (F12 on the
laptops, F11 on the towers) if someone is at the keyboard.

The installer is reachable over ssh as **`nixos@<ip>`** with the builder key, with
passwordless sudo. That is the honest completion check —
`systemctl is-active ghaf-installer-tui.service` and `/proc/cmdline` on the booted machine —
rather than inferring success from server logs.

If nothing appears in the server log, work outwards in this order: is the firewall open, did
the firmware emit a PXE request at all (`tcpdump -i <iface> -e -vv 'udp port 67 or 69 or
4011'` — a real PXE request carries `PXEClient` and option 93), and does the MAC on the wire
match the allowlist.

### The decisive log line is `Sending ipxe boot script`

Everything before it can succeed while the boot still fails. Read the log by which of these
it looks like:

| What the log does | What it means |
| --- | --- |
| Reaches `Sending ipxe boot script` | iPXE got DHCP and is chaining. This is the good case. |
| A fresh `Got valid request ... (X64)` every ~35 s, forever | iPXE loaded but its own DHCP is failing — it retries ten times and reboots. |
| Serves the iPXE binary again every ~20 s | Chainload loop: the iPXE being served has no embedded `user-class pixiecore` script. |
| Nothing at all | Firewall, or the firmware never emitted a PXE request. See above. |

The server serves its own `snponly.efi`, which uses the **firmware's** SNP driver and embeds
the `user-class pixiecore` handshake, so both loop cases should be history. If one reappears,
check `--dry-run`'s reported `ipxe` path is that binary rather than `pixiecore built-in`.
`--ipxe builtin` is the deliberate fallback for an adapter the firmware's SNP does not cover.

**Recovery from either loop can need physical access.** A separately powered USB-C dock keeps
its state across a laptop power cycle, so unplugging the dock is what actually clears it — do
not burn time on reboots that cannot work.

Every artefact can be served with a 200 while the target sits in an emergency shell. Assert on
the booted system, never on the transport.

## After deploying

Wait for it to come back, then confirm what is actually running rather than assuming:

```bash
until ssh -o ConnectTimeout=5 -o BatchMode=yes ghaf@<host_ip> -- true 2>/dev/null; do sleep 5; done
ssh ghaf@<host_ip> -- ssh ghaf-host  readlink /run/current-system
ssh ghaf@<host_ip> -- ssh gui-vm     readlink /run/current-system
ssh ghaf@<host_ip> -- ssh docker-vm  readlink /run/current-system
```

Compare that store path against what you built. A mismatch means the switch went to a
different generation, the VM was not restarted, or the device booted an older entry — all of
which look identical to "my fix didn't work" until you check.

Take an `fmo-logs` snapshot immediately after a deploy, while the state is fresh. If you have
a baseline from before, the diff tells you what your change did to the system rather than
what the system happens to log.

If the device does not come back at all, go to `fmo-connect` and capture serial before
power-cycling — the boot that failed is the evidence, and a power cycle destroys it.

<!-- Ported from ghaf .claude/skills/ghaf-deploy/SKILL.md @ 2b01173b. Divergences: just rebuild instead
     of ghaf-rebuild, ISO + ghaf-installer instead of ghaf-flash of a raw image, no Jetson recovery
     mode, FMO machine netboot quirks, docker-vm restart/persistence addendum. -->
