# Modules and Examples

## Core Module: `quick-vm`

The `quick-vm` module is the foundation of the project. It creates a **single VM** with:

- **Dynamic networks** — attach any number of interfaces via `networks = [...]` list
- **OS profiles** — built-in (`os_name`) or custom (`os_profile`) with automatic image download
- **Shared base volumes** — pass `os_volume` from `quick-os-volume` for thin provisioning
- **Disk modes** — `backing_store` (thin, fast) or `clone` (full copy, independent)
- **Network profile** via `profile` (object) or `profile_name` (string — auto-reads from libvirt)
- **Global network control** — `kvm-networks` map to enable/disable networks across all VMs

### Built-in OS Profiles

| `os_name` | Image (local) | Image (URL) | Network |
|-----------|---------------|-------------|---------|
| `ubuntu_22` | `ubuntu-2204.qcow2.base` | cloud-images.ubuntu.com | netplan, `enp0s` |
| `ubuntu_24` | `ubuntu-2404.qcow2.base` | cloud-images.ubuntu.com | netplan, `enp0s` |
| `rocky_9` | `rocky-9.qcow2.base` | dl.rockylinux.org | networkmanager, `eth` |
| `debian_12` | `debian-12.qcow2.base` | cloud.debian.org | netplan, `enp0s` |

## Multi-VM Setup: `quick-vms`

The `quick-vms` module creates a **set of VMs** based on a machines configuration. It automates:

- Provisioning of multiple VMs with shared or standalone OS volumes
- Network profile reading and filtering via `kvm-networks` map
- Access helpers (`.qv-access/`) — render `ssh-config`, `/etc/hosts`, and Ansible inventory via [`quick-access-ssh`](./USAGE.md#quick-access-ssh) / [`quick-access-hosts`](./USAGE.md#quick-access-hosts) / [`quick-access-ansible`](./USAGE.md#quick-access-ansible)

Ensure your cloud-init configuration includes your **public SSH key** to enable passwordless access.

## Modules Overview

Each module is located in the [`modules`](../modules) directory:

| Module | Description |
|--------|-------------|
| [`quick-vm`](../modules/quick-vm) | Provision a single VM with dynamic networks, OS profiles, and disk modes. Supports `vm_profile.{cpu,io,network}` + `enable_config` for KVM-API XML inject throttle (Path A). |
| [`quick-vms`](../modules/quick-vms) | Provision multiple VMs as named sets sharing OS image and profile |
| [`quick-os-volume`](../modules/quick-os-volume) | Create shared base OS volume for thin provisioning across VMs |
| [`quick-networks`](../modules/quick-networks) | Create KVM virtual networks (NAT and bridge) |
| [`quick-kvm-network-reader`](../modules/quick-kvm-network-reader) | Read and expose KVM network info via shell script |
| [`quick-access-ssh`](../modules/quick-access-ssh) | Render an `ssh-config` (one file per deployment) from `vms_info` groups |
| [`quick-access-hosts`](../modules/quick-access-hosts) | Render an `/etc/hosts`-style file from `vms_info` groups |
| [`quick-access-ansible`](../modules/quick-access-ansible) | Render an Ansible `inventory.ini` with groups + `[all:vars]` SSH/become config |
| [`quick-throttle`](../modules/quick-throttle) | **Live-apply throttle (Path B, axis 1/3):** generate `.qv-limits/<prefix>-{cpu,disk,network}-<name>.ini` profile definitions from named collections per axis. |
| [`quick-throttle-apply`](../modules/quick-throttle-apply) | **Live-apply throttle (Path B, axis 2/3):** generate `.qv-limits/<prefix>-throttle.ini` mapping file binding VMs to profiles (bootstrap all-null, edit manually). |
| [`quick-throttle-runner`](../modules/quick-throttle-runner) | **Live-apply throttle (Path B, axis 3/3):** generate generic `.qv-limits/qv-throttle.{apply,clear}.sh` scripts that consume a mapping file and drive `virsh`. |

## Examples

The [`examples`](../examples) directory demonstrates how to use the modules:

| Example | Description |
|---------|-------------|
| [`prerequisites/01-networks-nat-bridge`](../examples/prerequisites/01-networks-nat-bridge) | Create KVM networks (NAT + bridge) |
| [`01-network-reader-info`](../examples/01-network-reader-info) | Read and display network parameters |
| [`02a-vm-network-variants`](../examples/02a-vm-network-variants) | Single VMs with various network configs (static, DHCP, profile_name) |
| [`02b-vm-custom-storage`](../examples/02b-vm-custom-storage) | Single VMs with custom storage and network configs |
| [`02c-vm-os-image-modes`](../examples/02c-vm-os-image-modes) | OS image modes: shared os_volume, standalone os_name, custom os_profile |
| [`03-vms-masters-workers`](../examples/03-vms-masters-workers) | Multiple VMs (masters + workers) with quick-vms |
| [`04-vms-shared-os-volume`](../examples/04-vms-shared-os-volume) | Multiple quick-vms instances sharing one base volume, clone vs backing_store |
| [`05-vms-throttle-limits`](../examples/05-vms-throttle-limits) | Resource limits — demonstrates **both paths**: Path A (`enable_config` XML inject on single VM) and Path B (`quick-throttle*` triplet on a 3-node worker set with chaos workflow) |
| [`06-vms-access-helpers`](../examples/06-vms-access-helpers) | Multiple quick-vms instances + standalone VM, with `quick-access-ssh`/`hosts`/`ansible` and group helpers |