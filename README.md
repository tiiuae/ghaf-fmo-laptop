<!--
    Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# TII SSRC Secure Technologies: Ghaf FMO Laptop

<div align="center">

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-darkgreen.svg)](./LICENSES/LICENSE.Apache-2.0) [![License: CC-BY-SA 4.0](https://img.shields.io/badge/License-CC--BY--SA--4.0-orange.svg)](./LICENSES/LICENSE.CC-BY-SA-4.0) [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/10193/badge)](https://www.bestpractices.dev/projects/10193) [![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](./CODE_OF_CONDUCT.md) 

</div>

This repository contains the source files (code and documentation) of Ghaf-fmo-laptop — an open-source project for enhancing security through compartmentalization on edge devices.



### Documentation



## Other Project Repositories


## Build System

Ghaf-fmo-laptop images are built and tested by our continuous integration system. For more information on a general process, see [Continuous Integration and Distribution](https://tiiuae.github.io/ghaf/scs/ci-cd-system.html).

### Generate a Personal Access token

As the repo contains references to a number of private repositories it is necessary to generate a [Personal Access Token (PAT)](https://github.com/settings/personal-access-tokens/new) that has read access to the repositories. It is possible to provide access to only the required repos or you could create a token with read access to the [TIIUAE organization](https://github.com/tiiuae).

Currently the following dependency go repositories require access tokens:

* https://github.com/tiiuae/go-configloader
* https://github.com/tiiuae/fleet-manager
* https://github.com/tiiuae/provisioning-server

From the PAT menu add a title, description, select `TIIUAE` as the `Resource owner`, choose a reasonable Expiration date (upto 1 year). Choose `All Repos`, or select required ones, and from `Repository Permissions` choose `Contents` and select `Read-only`. Then `Generate Token` to create and save the token. Remember to record the token before closing the page as it is not recoverable and you will have to generate it again.

You will need to store that token in e.g. your `~/.netrc` file in .netrc format.

`machine github.com login x-access-token password <token>`

Where <token> is a GitHub token that you created above.

### Quick start guide for first time install

Example of building the `Lenovo X1`` target and flashing for first time:

``` shell
# set up the build environment
nix develop

# See the list of targets that can be built
nix flake show

# or use the convenience wrapper

just show

# select a target to build and provide extra arguments instead of "" if any
just build .#fmo-lenovo-x1-gen11-debug-installer ""

# insert an ssd to copy the installer to and find the name e.g. /dev/sdb
sudo lsblk

# flash the installer to the ssd
sudo dd if=./result/iso/ghaf.iso of=/dev/sdb bs=32M status=progress; sync

# install into the target machine (ensure bios is configured to boot from ssd)
# boot to the cmd prompt

sudo ghaf-installer

#select the target disk
/dev/nvme0n1

# accept that you are going to erase the disk
y

# after install reboot and remove the ssd
sudo reboot

#after boot choose username / fullname / password (twice)
username / username / password

# once created login with the new credentials
username / password

```

### Installing over the network (netboot)

Netboot performs the same install as the ISO above — the same TUI, the same disk write — without a USB stick. The difference is where the image comes from: it is fetched over HTTP during the install rather than baked into the media, so the netboot artefacts are a kernel, an initrd and a small iPXE script instead of a ~7 GB image. The kernel and initrd are the same for every target, so one build serves the whole fleet.

Secure Boot must be **off** on the target: the netboot chain is unsigned, exactly as the ISO is.

``` shell
nix develop

# the installer environment, and the image it will fetch - both are needed
just build .#fmo-lenovo-x1-gen11-debug-netboot-installer "-o result-netboot"
just build .#fmo-lenovo-x1-gen11-debug "-o result"

# check what will be served, and on which interface, before touching the network
ghaf-netboot -i <iface> -m <target-mac> -n result-netboot -g result --dry-run

# then serve it for real; the target is allow-listed by MAC, so nothing else on
# the network is offered a boot image
ghaf-netboot -i <iface> -m <target-mac> -n result-netboot -g result \
  --open-firewall --exit-after-serve
```

Then power on the target and pick the network entry from its boot menu (`F12` on the Lenovo and Dell machines, `F11` on the towers). See `ghaf-netboot --help` for unattended installs (`--install-target`, `--encrypt`) and the other options.

Two hardware notes worth knowing before blaming the server:

* The Lenovo X1 has no built-in RJ45. A generic USB-C ethernet dongle emits no PXE request at all — the firmware has no UEFI driver for it. Use a Lenovo dock, and note that the MAC to allow-list is the **dock's**, not the one the installed OS reports.
* The Dell Latitude 7330 publishes several network boot entries on the same MAC. Use `ONBOARD NIC (IPV4)`; `UEFI HTTPs Boot` announces a DHCP architecture that the server discards.

### Building every target

``` shell
# every installer ISO, and with them every disk image, each to its own
# result-<target> link
just build-all

# every netboot installer; only the first costs anything, since the kernel and
# initrd are shared. NB this builds boot environments, not images - a netboot
# install still serves an image built by `just build`, as shown above.
just build-netboot
```

### Rebuilding and flashing a target (after first install)

``` shell
# setup the development environment
nix develop

# the helper sets up the ProxyJump for you; see its options with
ghaf-build-helper --help

# use the helper tool to buid and flash your target
just rebuild 192.168.10.212 .#fmo-lenovo-x1-gen11-debug boot

# alternatively you can use the nix tooling directly without the wrapper - NB remember to copy your .netrc file to /tmp/.netrc before running
nixos-rebuild --flake .#fmo-lenovo-x1-gen11-debug --target-host "root@ghaf-host" --fast  --option builders '' --option extra-sandbox-paths "/tmp/.netrc" boot

```

### Specifying a different location for the NETRC_FILE

You can override the default location for the `.netrc` file by specifying it on the command line before any of the default commands.

``` shell
just NETRC_FILE=/home/user/.my-secrets build .#fmo-lenovo-x1-gen11-debug ""

```


## Contributing

We welcome your contributions to code and documentation.

If you would like to contribute, please read [CONTRIBUTING.md](CONTRIBUTING.md) and consider opening a pull request. One or more maintainers will use GitHub's review feature to review your pull request.

In case of any bugs or errors in the content, feel free to create an [issue](https://github.com/tiiuae/ghaf-fmo-laptop/issues). You can also [create an issue from code](https://docs.github.com/en/issues/tracking-your-work-with-issues/creating-an-issue#creating-an-issue-from-code).


## Licensing

The Ghaf-fmo-laptop team uses several licenses to distribute software and documentation:

| License Full Name | SPDX Short Identifier | Description |
| -------- | ----------- | ----------- |
| Apache License 2.0 | [Apache-2.0](https://spdx.org/licenses/Apache-2.0.html) | Ghaf source code. |
| Creative Commons Attribution Share Alike 4.0 International | [CC-BY-SA-4.0](https://spdx.org/licenses/CC-BY-SA-4.0.html) | Ghaf documentation. |

See [LICENSE.Apache-2.0](./LICENSES/Apache-2.0.txt) and [LICENSE.CC-BY-SA-4.0](./LICENSES/CC-BY-SA-4.0.txt) for the full license text.
