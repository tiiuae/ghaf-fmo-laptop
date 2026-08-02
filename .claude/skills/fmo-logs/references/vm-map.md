<!--
    Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# FMO VM map

Which VM owns what, and where to look when a signature shows up. Addresses verified by
evaluating `nixosConfigurations.fmo-dell-7330-debug.config.networking.hosts`.

Paths written as `ghaf:...` are in the **ghaf flake input**, not this tree — grepping here
for them finds nothing. See the upstream section of `fmo-target` for how to reach them.

## Responsibilities

| VM | Address | Responsible for | Look here when |
|---|---|---|---|
| net-vm | 192.168.100.1 | the physical NIC, `vlan_control` (VLAN 100), MTU 1372 on `ethint0`, avahi/mDNS publishing, and the `fmo-firewall` rules forwarding 4222/7222/6422/6423/123 to docker-vm | nothing is reachable, the mDNS name is wrong, NATS or NTP never reaches docker-vm |
| ghaf-host | 192.168.100.2 | the hypervisor, `microvm@*` units, PCI passthrough, disko and LUKS, `fmo-certs-distribution-service-host` (the NATS CA — the key stays host-only, deliberately), `/persist/common` and `/persist/fogdata` | a VM won't start, passthrough fails, boot or partitioning trouble, client certs missing inside a VM |
| audio-vm | 192.168.100.3 | PipeWire, bluetooth passthrough | no sound, bluetooth audio |
| gui-vm | 192.168.100.4 | the COSMIC desktop, greetd and login, GPU-accelerated browsers, display and input, fingerprint reader and webcam passthrough | no greeter, login fails, GPU or VAAPI trouble, a launcher entry does nothing |
| admin-vm | 192.168.100.5 | givc admin. **The journal collector is off** (`ghaf.logging.enable = false` in `modules/profile/fmo.nix`), so there is nothing aggregated here | inter-VM control fails |
| docker-vm | 192.168.100.101 | Docker and the DCI containers, `fmo-dci`, the onboarding agent, `fmo-docker-networking`, `fmo-dci-passthrough` (YubiKey, crazyradio), `/var/lib/fogdata`, the NATS client certs | onboarding fails, containers are down, a compose update fails, the VM's disk is full |

## Failure signature → where to look

| Signature | Likely VM | Module area |
|---|---|---|
| `fmo-dci.service` failing; compose pull/up; a `ghcr.io` 401 | docker-vm | `modules/fmo/fmo-dci-service/`, and on the device `/var/lib/fogdata/PAT.pat` and `cr.url` |
| `setup-onboarding-agent.service`; certificate or token errors | docker-vm | `modules/fmo/fmo-onboarding-agent/`, `/var/lib/fogdata/certs` |
| containers have no route; MTU or fragmentation trouble | docker-vm | `modules/fmo/fmo-docker-networking/`; MTU is 1372 on `ethint0` in both net-vm and docker-vm, so a mismatch shows as large transfers stalling while pings succeed |
| NATS refused on 4222/7222 from outside | net-vm | `modules/microvm/netvm.nix` (`fmo-firewall.configuration`), `modules/fmo/fmo-firewall/` |
| `/var/lib/nats/certs` empty in net-vm or docker-vm | ghaf-host **first** | `modules/microvm/host.nix` (`clients-paths`), `modules/fmo/fmo-certs-distribution-host/`. The unit that generates them is `openssl-certs-gen.service` on the host |
| the hostname or mDNS name is wrong, or resets | net-vm (avahi) and docker-vm (kernel hostname) | `modules/fmo/fmo-update-hostname/`, `/var/common/hostname` |
| a virtiofs mount is missing (`common_share_*`, `fogdatafs`, `nats_*`) | ghaf-host and the VM | `modules/microvm/{host,netvm}.nix`, `modules/microvm/docker/config.nix` |
| "No space left on device" in docker-vm | docker-vm | `modules/microvm/docker/config.nix` — guestStorage is capped at `62 * 1024` MiB |
| a VM is OOM-killed, host memory near zero | ghaf-host | `modules/hardware/resources/<machine>.nix` (`vmConfig`). Check you built *this* machine's target |
| `greetd`, `pam_*`, `cosmic-greeter` | gui-vm | `modules/microvm/guivm.nix` (which overrides greetd's hardening locally), `ghaf:modules/desktop/graphics/` |
| `microvm@<name>.service` failed | ghaf-host | `modules/microvm/`, `ghaf:modules/microvm/` |
| `vfio`, `iommu`, PCI bind errors | ghaf-host | `modules/hardware/`, `ghaf:modules/hardware/passthrough/` |
| `givc`, agent or admin connection refused | admin-vm and the peer | `ghaf:modules/givc/` |

### Unit names that are not what you would guess

- **There is no `fmo-update-hostname.service`.** The module of that name defines
  `fmo-update-avahi-hostname` and `fmo-update-kernel-hostname`, each with a matching
  `.path` unit watching `/var/common/hostname`. Asking systemd for the obvious name returns
  "not found", which reads as "the feature is not enabled".
- The certificate generator on the host is `openssl-certs-gen.service`, not anything with
  `fmo-certs` in the unit name.
- Onboarding runs as `setup-onboarding-agent.service`.

## Cross-VM dependency order

Establish which VM failed **first** from the manifest and each VM's own journal before
attributing blame. There is no aggregated timeline on an FMO device, so ordering has to be
reconstructed from per-VM timestamps.

The clause that matters most here: docker-VM's `fmo-dci` needs client certificates
distributed by ghaf-host *and* egress through net-vm, and onboarding writes into a share
ghaf-host owns. A docker-vm failure is downstream of one of those roughly as often as it is
a fault of its own — and docker-vm is the loudest VM on the device, so it is where an
untriaged investigation naturally starts and usually should not.
