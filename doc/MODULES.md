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
- SSH configuration generation (`qv-ssh-config-*.qv-info`)
- Hosts file generation (`qv-hosts-*.qv-info`)

Ensure your cloud-init configuration includes your **public SSH key** to enable passwordless access.

## Modules Overview

Each module is located in the [`modules`](../modules) directory:

| Module | Description |
|--------|-------------|
| [`quick-vm`](../modules/quick-vm) | Provision a single VM with dynamic networks, OS profiles, and disk modes |
| [`quick-vms`](../modules/quick-vms) | Provision multiple VMs with shared network config and SSH/hosts generation |
| [`quick-os-volume`](../modules/quick-os-volume) | Create shared base OS volume for thin provisioning across VMs |
| [`quick-networks`](../modules/quick-networks) | Create KVM virtual networks (NAT and bridge) |
| [`quick-kvm-network-reader`](../modules/quick-kvm-network-reader) | Read and expose KVM network info via shell script |
| [`quick-ssh-config`](../modules/quick-ssh-config) | Generate SSH config with usage instructions |
| [`quick-hosts`](../modules/quick-hosts) | Generate `hosts` entries for VMs |

## Examples

The [`examples`](../examples) directory demonstrates how to use the modules:

| Example | Description |
|---------|-------------|
| [`example1-network`](../examples/example1-network) | Create KVM networks (NAT + bridge) |
| [`example2-kvm-network-reader`](../examples/example2-kvm-network-reader) | Read and display network parameters |
| [`example3a-vm`](../examples/example3a-vm) | Single VMs with various network configs (static, DHCP, profile_name) |
| [`example3b-vm`](../examples/example3b-vm) | Single VMs with custom storage and network configs |
| [`example3c-vm`](../examples/example3c-vm) | OS image modes: shared os_volume, standalone os_name, custom os_profile |
| [`example4-vms`](../examples/example4-vms) | Multiple VMs (masters + workers) with quick-vms |
| [`example5-vms`](../examples/example5-vms) | Multiple quick-vms instances sharing one base volume, clone vs backing_store |