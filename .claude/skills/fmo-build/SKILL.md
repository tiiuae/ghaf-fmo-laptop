---
name: fmo-build
description: Build FMO images, installers and netboot artefacts - picking the right target name, why every build goes through `just` and the .netrc, checking what a build will cost before starting it, and reading this repo's common eval failures. Use whenever asked to build an FMO image, installer or netboot target, to check whether something still builds or evaluates, or before deploying a change to a device. Also use when a nix build or eval fails in this repo and the error needs interpreting. This is the FMO counterpart of ghaf's ghaf-build skill; use it when someone asks for "ghaf-build" in this repo.
---

# Building FMO images

Most of the cost here is choosing correctly before you start. Two things make this repo
unlike upstream Ghaf: builds need credentials that only `just` supplies, and **nothing
`fmo-*` is ever cached**, so every target builds from source on one machine, every time.

## Builds go through `just`, and it is not a convenience

Several Go dependencies are private TII repositories — `go-configloader`, `fleet-manager`,
`provisioning-server` — fetched *inside* the Nix sandbox. The justfile installs `~/.netrc`
at `/tmp/.netrc` and passes `--option extra-sandbox-paths` so the sandbox can read it:

```bash
just build .#fmo-dell-7330-debug ""            # the "" is the mandatory +rest argument
just build .#fmo-dell-7330-debug "-L"          # stream build logs
just build .#fmo-dell-7330-debug "-o result-x1"
just NETRC_FILE=/path/to/.netrc build .#fmo-dell-7330-debug ""
```

A bare `nix build .#fmo-…` fails in the vendor fetch with a credentials error that reads
like a network fault, which is why this is worth stating before anything else.

Mode 644 on `/tmp/.netrc` is deliberate, not sloppiness: the sandbox builder runs as a
different user and needs both a traversable directory and a readable file. A private
`mktemp` directory or mode 0600 fails at sandbox setup with "getting attributes of path …:
Permission denied".

`--option builders ''` is in every image recipe because a remote builder would not have the
credentials. Unlike upstream, that is not a choice you can reverse — there is no aarch64
work here to delegate anyway (`flake.nix` sets `systems = [ "x86_64-linux" ]`).

## Pick the target

One machine, one target — see `fmo-target` for the full table and the trap. The naming is
`fmo-<machine>-debug`, optionally `-installer` or `-netboot-installer`. Only the `debug`
variant exists today; `release` is commented out in `targets/flake-module.nix`.

Get the exact string from the device config rather than assembling it by hand:

```bash
.claude/scripts/fmo-config.py --device dell-7330 --field fmo_target
.claude/scripts/fmo-config.py --device dell-7330 --field installer_target
.claude/scripts/fmo-config.py --device dell-7330 --field netboot_target
```

To confirm a name exists before spending anything on it:

```bash
just show                                       # nix flake show
nix eval .#packages.x86_64-linux --apply \
  'ps: builtins.elem "fmo-dell-7330-debug" (builtins.attrNames ps)'
```

## Find out what you are committing to

`nix build --dry-run` needs no credentials, so it is safe to run bare and there is no reason
to skip it:

```bash
nix build --dry-run .#fmo-dell-7330-debug
```

Read the two lists it prints: "will be fetched" is cheap, "will be built" is not. But
calibrate differently from upstream. `ghaf-dev.cachix.org` is declared in this repo's
`flake.nix` and covers *ghaf's* outputs — the kernel, the desktop, the system-VM closures.
Nothing named `fmo-*` is pushed there by anyone, so an FMO image target always has a
substantial "will be built" list and always builds locally. Hundreds of derivations after a
one-line change to `modules/fmo/` still means something moved deep — a bumped input, an
overlay applied globally — and is worth checking before letting it run.

## Build everything

```bash
just build-all        # every ISO installer, and so every disk image, to result-<target>
just build-netboot    # every netboot installer
```

`build-all` builds the installers rather than the images because an installer takes its
target's image as an input, so it covers both and there is nothing extra to do. It is a
long, serial, local run over seven targets.

`build-netboot` is the cheap one and the only recipe here with no netrc: a netboot installer
is ghaf's installer system plus a three-symlink linkFarm and pulls in no FMO package, so
there is nothing for the credentials to unlock. Only the first target costs anything — the
kernel and initrd are target-independent and shared, so the other six are symlinks over a
closure that is already built.

`nix-fast-build` is in the devshell but has no netrc plumbing, so for FMO images you must
install the credentials yourself first, exactly as the justfile does:

```bash
install -m 644 ~/.netrc /tmp/.netrc
nix-fast-build --flake '.#packages.x86_64-linux' \
  --select 'ps: builtins.removeAttrs ps (builtins.filter (n: builtins.match "fmo-.*-debug" n == null) (builtins.attrNames ps))' \
  --skip-cached --no-link \
  --option builders '' --option extra-sandbox-paths "/tmp/.netrc"
rm -f /tmp/.netrc
```

`just build-all` is the supported path; reach for the above only when you want its
parallelism and are willing to manage the credentials by hand.

## What the build produces

Three target families, three different output layouts. Getting this wrong is how you end up
pointing a flashing tool at a path that does not exist:

```
fmo-<m>-debug                    result/ghaf-image.raw.zst   the compressed image
                                 result/ghaf-image.bmap      block map, used automatically

fmo-<m>-debug-installer          result/iso/ghaf.iso         the bootable installer ISO
                                 (just build-all writes result-<target>/iso/ghaf.iso)

fmo-<m>-debug-netboot-installer  bzImage, initrd, netboot.ipxe
```

The image names come from `ghaf:modules/partitioning/disko-debug-partition.nix`, and the ISO
is always `ghaf.iso` regardless of target, because `image.baseName` is set in
`ghaf:lib/builders/installer-common.nix`. Do not expect the target name in the filename.

**The netboot output is a linkFarm — symlinks into `/nix/store`.** Copy it with `cp -L` or
`rsync -L` when staging it onto a TFTP or HTTP root, or the server serves dangling links and
the target fails with something that looks like a network problem.

## Checking the whole flake

`nix flake check` builds every package — seven images, seven ISOs, seven netboot installers
— so it needs the credentials and it is not a quick check:

```bash
install -m 644 ~/.netrc /tmp/.netrc
nix flake check --option builders '' --option extra-sandbox-paths "/tmp/.netrc"
rm -f /tmp/.netrc
```

`nix/checks.nix` derives those checks from `self'.packages` automatically, so every target
added to `targets/flake-module.nix` becomes a CI check without anyone opting in.

## Reading this repo's eval failures

- **IFD errors** — `allow-import-from-derivation = false` is set in this `flake.nix` on
  purpose. Fix the expression; do not enable IFD to get past it.
- **`Path '…' in the repository is not tracked by Git`** — flakes ignore untracked files.
  `git add -N <path>` makes a new file visible without staging its content. This also
  affects the `reuse` check, which runs over the flake source.
- **Input skew after a partial bump.** `ghaf`, `nixpkgs`, `flake-parts` and
  `onboarding-agent` are coupled and want bumping as a set — `nixpkgs` follows `ghaf/nixpkgs`,
  so moving `ghaf` alone moves nixpkgs underneath everything else.
- **`nix flake update` failing at lock time, not build time.** `onboarding-agent` is a
  `git+ssh://git@github.com/tiiuae/onboarding-agent` input, so it needs an ssh agent with
  access to tiiuae. Without one it fails while locking, which looks unrelated to the input.
- **Something upstream "does not exist".** Most modules are in the `ghaf` input, not this
  tree. See the upstream-is-in-the-store section of `fmo-target` before concluding a module
  is missing.
- **A dirty tree changes the flake source hash**, so `versionRev` in
  `targets/flake-module.nix` falls back to a `dirtyShortRev` and anything embedding it
  rebuilds. That is expected, not a fault.

<!-- Ported from ghaf .claude/skills/ghaf-build/SKILL.md @ 2b01173b. Divergences: the just/.netrc build
     path, no cache for fmo-* outputs, three artefact families including netboot, no Jetson or aarch64,
     FMO's input coupling instead of ghaf's nixpkgs-bump failure mode. -->
