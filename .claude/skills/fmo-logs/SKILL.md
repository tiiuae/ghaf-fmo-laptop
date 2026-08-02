---
name: fmo-logs
description: Collect journals and unit state from every VM on an FMO device (ghaf-host, net-vm, gui-vm, audio-vm, admin-vm, docker-vm) and diff two snapshots to separate a regression from noise that was always there. Use this whenever something broke on a device after a change, install or update, when asked what went wrong, why a VM or service failed, why onboarding or the containers are not running, whether a change regressed anything, or to check the logs, journal or systemd state of ghaf-host or any VM. Also use it before proposing a fix for any runtime failure, so the diagnosis rests on evidence rather than a guess. This is the FMO counterpart of ghaf's ghaf-logs skill; use it when someone asks for "ghaf-logs" in this repo.
---

# FMO log collection and regression hunting

An FMO device logs from six places at once. Two problems follow: the evidence you need is
scattered across VMs, and a healthy boot already contains plenty of errors. This skill solves
both — snapshot everything, then compare against a known-good snapshot so the only thing you
read is what actually changed.

Read `fmo-target` for the address map, and
`.claude/skills/fmo-logs/references/vm-map.md` for what each VM owns. Analysis belongs to the
`fmo-log-triage` agent — hand it the snapshot rather than reading tens of thousands of
journal lines yourself.

## Take a snapshot

```bash
.claude/skills/fmo-logs/scripts/collect-logs.sh --machine dell-7330
.claude/skills/fmo-logs/scripts/collect-logs.sh --ip 192.168.1.50 --out fmo-logs/after-fix
```

It asks the device which VMs exist (`microvm@*` units plus `/etc/hosts`) rather than assuming
a fleet, collects in parallel over one multiplexed ssh connection, and writes:

```
<dir>/manifest.txt        when, where, repo rev, ghaf input rev, deployed store path per VM
<dir>/ghaf-host/          journal, failed units, dmesg, /proc/cmdline, microvm units
<dir>/docker-vm/          the above plus docker ps, the docker journal, the fmo-* units,
                          /var/lib/fogdata and disk usage
<dir>/<vm>/               journal, failed units, running system
<dir>/<vm>/UNREACHABLE.txt   present when that VM did not answer
```

A VM that should be there and isn't — or that answers nowhere — is a finding in itself, so
the collector records absence instead of failing.

The docker-VM extras exist because the FMO payload lives there and none of it shows up in a
generic journal collection. Disk usage is in that list for a specific reason: the VM's
guestStorage is capped in `modules/microvm/docker/config.nix`, so "no space left" is a real
and otherwise invisible failure mode that presents as containers refusing to start.

`manifest.txt` records **both** `repo_rev` and `ghaf_rev`. What is deployed depends on the
`ghaf` input as much as on this tree, so a snapshot that records only the repo revision
cannot answer "what changed since this device was last good".

**Keep a known-good snapshot.** Take one when the device is healthy, before you change
anything. Without a baseline you are reduced to guessing which of the errors on screen
matter, which is exactly the trap this skill exists to avoid.

## Diff against the baseline

```bash
.claude/skills/fmo-logs/scripts/diff-logs.py fmo-logs/known-good fmo-logs/after-fix
```

The diff normalises timestamps, PIDs, store hashes, UUIDs, MACs and addresses before
comparing, because those vary between boots without meaning anything and would otherwise make
every line look new. It leads with units that fail now but didn't before — usually the
headline — then new journal lines, filtered to things that look like problems. `--all` shows
everything; `--max-per-file` raises the cap, and any lines it drops are counted, not silently
hidden.

Exit status is 1 when it finds something, so an unattended loop can branch on it.

## There is no aggregated timeline here

Ghaf can forward journals to a collector on admin-vm rather than leaving them on each VM
(`ghaf:modules/common/logging/`), but **`modules/profile/fmo.nix` sets
`ghaf.logging.enable = false`**, so on an FMO device that is off. Per-VM collection is not
merely the preferred route, it is the only one, and admin-vm holds nothing cross-VM.

The consequence for diagnosis: ordering *between* VMs has to be reconstructed from the
per-VM journals' own timestamps rather than read off a single stream. When a failure spans
VMs — certs distributed by ghaf-host, egress through net-vm, containers in docker-vm — that
reconstruction is the work, and the collector's parallel snapshot is what makes it possible.

If someone does turn logging on, the aggregated view is:

```bash
ssh ghaf@<host_ip> -- ssh admin-vm \
  journalctl -D /var/log/journal/remote --no-pager --since -30min
```

It can lag or drop entries if the network was part of the failure, so do not treat its
silence as proof that nothing happened.

## Reading the result

Hand the snapshot directory to the `fmo-log-triage` agent. It returns ranked findings with
the VM, unit, first occurrence and a suspected module path — you get the conclusions rather
than the journal.

Three habits that repeatedly matter:

- **Earliest, not loudest.** systemd reports a failed unit long after the thing that made it
  fail. The first error inside that unit's own logs is the one to read.
- **Confirm what is actually running.** `manifest.txt` records each VM's
  `/run/current-system`. If that store path is in your local store you can read the exact
  generated configuration — `/nix/store/<hash>-nixos-system-<vm>-*/etc/` — instead of
  re-deriving what you assume the Nix produced. This matters more here than upstream: most of
  the modules that generated those files are in the `ghaf` input, so the rendered `etc/` is
  the only copy within reach without checking the input out. It is how the greetd PAM
  regression was pinned down upstream — the rendered `etc/pam.d/greetd` settled in seconds
  what the module source had made ambiguous.
- **A docker-vm failure is downstream about as often as it is a fault.** Its services need
  client certificates distributed by ghaf-host and egress through net-vm. Establish which VM
  failed *first* before attributing blame to the one that is complaining loudest.

<!-- Ported from ghaf .claude/skills/ghaf-logs/SKILL.md @ 2b01173b. Divergences: docker-vm extras and
     ghaf_rev in the snapshot, central logging inverted (off by default in FMO), the downstream-failure
     habit added. -->
