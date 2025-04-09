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

# select a target to build
just build .#fmo-lenovo-x1-gen11-debug-installer

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

### Rebuilding and flashing a target (after first install)

``` shell
# setup the development environment
nix develop

# see the documentation on setting up the ssh config (especially the proxyJump)
# only needs to be done once.
cat .packages/fmo-build-helper/default.nix

# use the helper tool to buid and flash your target
just rebuild 192.168.10.212 .#fmo-lenovo-x1-gen11-debug boot

# alternatively you can use the nix tooling directly without the wrapper - NB remember to copy your .netrc file to /tmp/.netrc before running
nixos-rebuild --flake .#fmo-lenovo-x1-gen11-debug --target-host "root@ghaf-host" --fast  --option builders '' --option extra-sandbox-paths "/tmp/.netrc" boot

```

### Specifying a different location for the NETRC_FILE

You can override the default location for the `.netrc` file by specifying it on the command line before any of the default commands.

``` shell
just NETRC_FILE=/home/user/.my-secrets build .#fmo-lenovo-x1-gen11-debug

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
