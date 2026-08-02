<!--
    Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# ghaf-fmo-laptop — instructions for coding agents

This repo builds FMO laptop and tower images on top of Ghaf. It is a downstream flake-parts
overlay: `ghaf` is a flake input, and most of what ends up on a device — the microVM
machinery, the desktop, givc, partitioning, networking — comes from there. What lives here
is seven target definitions, per-machine hardware resources, the FMO service modules, and a
docker-VM that Ghaf itself does not have.

This file is the shared instruction set for every agent working in this repo. Detailed
procedures live in skills (see [Where the depth is](#where-the-depth-is)); keep this file
short and limited to things that are true for all work.

## Before you commit

```bash
nix fmt -- --fail-on-change          # treefmt: nixfmt, deadnix, statix, ruff, shellcheck, prettier
nix develop --command reuse lint     # every file needs SPDX copyright + licence
```

`nix flake check` builds all seven images **and** all seven ISO installers, and those need
the netrc inside the sandbox (see below). It cannot be run bare here:

```bash
install -m 644 ~/.netrc /tmp/.netrc
nix flake check --option builders '' --option extra-sandbox-paths "/tmp/.netrc"
rm -f /tmp/.netrc
```

treefmt here excludes `*.md`, `*.toml` and `*.txt`, so markdown is **not** reformatted for
you — match the surrounding style by hand. YAML *is* formatted. There is no shfmt; shell
only has to satisfy shellcheck.

New files need an SPDX header — Apache-2.0 for code, CC-BY-SA-4.0 for documentation:

```nix
# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
```

If a file cannot carry a header — YAML frontmatter has to come first — add it to the
annotations block in `REUSE.toml` instead.

Commit subjects follow the existing log's `scope: Sentence` form: `fmo-certs: Keep the NATS
CA key off the guests`, `just: Add a build-all recipe for the installers`. Do not commit or
push unless you were asked to.

## Building needs a ~/.netrc, so builds go through `just`

Several Go dependencies are private TII repositories (`go-configloader`, `fleet-manager`,
`provisioning-server`) fetched *inside* the Nix sandbox. The justfile installs `~/.netrc` at
`/tmp/.netrc` — mode 644, because the sandbox builder is a different user and needs both a
traversable directory and a readable file — and passes `--option extra-sandbox-paths`. A
bare `nix build .#fmo-…` fails in the vendor fetch with a credentials error that reads like
a network fault.

```bash
just show                                        # nix flake show
just build .#fmo-dell-7330-debug ""              # the "" is the mandatory +rest argument
just build .#fmo-dell-7330-debug "-L"            # stream build logs
just build-all                                   # every ISO installer, and so every image
just build-netboot                               # every netboot installer
just rebuild <netvm-ip> .#fmo-dell-7330-debug boot
just NETRC_FILE=/path/to/.netrc build .#fmo-dell-7330-debug ""
```

Remote builders are disabled in those recipes (`--option builders ''`) because a remote
builder would not have the credentials. `build-netboot` is the exception and says why: a
netboot installer pulls in no FMO package, so there is nothing for the credentials to
unlock.

`ghaf-dev.cachix.org` carries *ghaf's* outputs. Nothing named `fmo-*` is ever pushed there,
so every FMO target builds locally, every time, on one machine. Budget accordingly, and
check `nix build --dry-run` (which needs no netrc) before committing to a long build.

## Layout

- `targets/flake-module.nix` — every target, in one file. `fmo-configuration` wraps
  `ghaf.builders.mkGhafConfiguration`; installers come from `mkGhafInstaller` and
  `mkGhafNetbootInstaller`.
- `modules/hardware/` — `flake-module.nix` layers per-machine USB and PCI overrides over
  ghaf's hardware modules; `resources/<machine>.nix` sizes that machine's VM memory and vcpus.
- `modules/microvm/` — `host.nix`, `guivm.nix`, `netvm.nix`, `docker/{vm,config}.nix`
- `modules/fmo/` — the FMO services: `fmo-dci-service`, `fmo-dci-passthrough`,
  `fmo-firewall`, `fmo-certs-distribution-host`, `fmo-onboarding-agent`,
  `fmo-update-hostname`, `fmo-docker-networking`
- `modules/profile/` — `fmo.nix` (the profile: VM set, passthrough, partitioning,
  encryption) and `personalize.nix` (`fmo.personalize.debug.*`)
- `packages/`, `overlays/`, `nix/{checks,devshell,treefmt}.nix`

FMO-specific options go under `fmo.*`, layered over ghaf's `ghaf.*`:

```nix
{ config, lib, ... }:
let cfg = config.fmo.<module-name>;
in {
  options.fmo.<module-name>.enable = lib.mkEnableOption "<feature>";
  config = lib.mkIf cfg.enable { };
}
```

## Everyday commands

| Task | Command | Depth |
|---|---|---|
| List targets | `just show` | `fmo-build` |
| See what a build will cost | `nix build --dry-run .#fmo-<machine>-debug` | `fmo-build` |
| Build an image | `just build .#fmo-dell-7330-debug ""` | `fmo-build` |
| Build every installer | `just build-all`, `just build-netboot` | `fmo-build` |
| Deploy without reinstalling | `just rebuild <netvm-ip> .#fmo-<machine>-debug boot` | `fmo-deploy` |
| First install | build `-installer`, `dd` `iso/ghaf.iso`, `sudo ghaf-installer` | `fmo-deploy` |
| Install over the network | `ghaf-netboot -i <iface> -m <mac> -n … -g …` | `fmo-deploy` |
| Reach a device or VM | `ssh ghaf@<host_ip>`, then `ssh <vm>` from there | `fmo-connect` |
| Collect logs across VMs | `.claude/skills/fmo-logs/scripts/collect-logs.sh --machine <name>` | `fmo-logs` |

Device details — addresses, drives, serial nodes, target names per machine — live in
`.claude/config.yaml`, with the desk-local values in the gitignored
`.claude/config.local.yaml` beside it. Read them with `.claude/scripts/fmo-config.py` rather
than asking or guessing; if a field is null in both, ask once and offer to write it to the
**local** file.

## Things that bite

- **Ghaf is a flake input, so most modules are not in this tree.** Grepping here for
  `hosts.nix`, `login-manager.nix` or `microvm/sysvms/` finds nothing. Get the pinned
  checkout with `nix flake metadata --json | jq -r '.locks.nodes.ghaf.locked.rev'`, and
  cite upstream paths as `ghaf:modules/...` so nobody searches the wrong tree.
- **A bare `nix build` fails on the private Go dependencies.** Use `just`.
- **One machine, one target.** There is no generic laptop image here, unlike upstream.
  Building a neighbouring machine's target boots and then over-allocates VM memory or passes
  through the wrong devices — `modules/hardware/resources/<machine>.nix` is sized against
  that machine's actual RAM, and `dell-7230` has under 8 GiB in total.
- **Three artefacts per machine, three different output paths.**
  `fmo-<m>-debug` → `result/ghaf-image.raw.zst` (+ `ghaf-image.bmap`);
  `fmo-<m>-debug-installer` → `result-<target>/iso/ghaf.iso`;
  `fmo-<m>-debug-netboot-installer` → a linkFarm of `bzImage`, `initrd`, `netboot.ipxe` —
  copy it with `cp -L` or `rsync -L`, or you stage dangling symlinks onto the server.
- **First install is the ISO plus `ghaf-installer` on the target**, not writing a raw image
  to the internal disk. Netboot delivers the same install without the USB stick, and needs
  Secure Boot off on the target.
- **`nixos-rebuild switch` cannot repartition, rewrite a bootloader, or change the kernel
  cmdline.** Those need a reinstall, and switching anyway leaves a device that quietly
  disagrees with your source tree. `.claude/skills/fmo-deploy/scripts/needs-reflash.sh`
  classifies a change; it cannot classify a `flake.lock` ghaf bump, and says so rather than
  implying the bump is inert.
- **A host switch does not restart the microVMs.** They keep their old configuration until
  `systemctl restart microvm@<vm>.service`. Restarting docker-VM does not reset its
  containers either: `/var/lib/docker` on its guestStorage and the `/persist/fogdata`
  virtiofs share both survive.
- **Bump the inputs as a set.** `ghaf`, `nixpkgs`, `flake-parts` and `onboarding-agent` are
  coupled. `onboarding-agent` is a `git+ssh://` input, so `nix flake update` needs an ssh
  agent with access to tiiuae, and fails at lock time rather than at build time without one.
- **Flakes ignore untracked files.** A new file is invisible to `nix build` — and to the
  `reuse` check, which runs over the flake source — until at least `git add -N`.

## Where the depth is

- `.claude/skills/fmo-*/SKILL.md` — the target contract, build, deploy, connect and logs.
  Claude Code loads these automatically; other agents should read them as documentation when
  the task matches. They are the FMO counterparts of ghaf's `ghaf-*` skills and deliberately
  diverge from them: different targets, a different build path, a different install story.
- `.claude/agents/fmo-log-triage.md` — reads a log snapshot in its own context and returns
  ranked findings. Use it rather than reading a fleet of journals inline.

## Related repositories

- [ghaf](https://github.com/tiiuae/ghaf) — the upstream framework, and this repo's main input
- [ghafpkgs](https://github.com/tiiuae/ghafpkgs) — Ghaf-specific packages
- [onboarding-agent](https://github.com/tiiuae/onboarding-agent) — private; needs ssh access
- [ghaf-infra](https://github.com/tiiuae/ghaf-infra) — CI/CD infrastructure
