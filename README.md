# Quick-Virt

**Quick-Virt** is a collection of Terraform modules and shell scripts designed to simplify the process of creating and managing KVM-based virtual machines (VMs) on Linux for development purposes.
The project was tested and run on **Ubuntu 24.04 LTS**.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Key Features

- Rapid creation of KVM networks and VMs using Terraform.
- Modular structure to support single VM or multiple node cluster provisioning.
- Dynamic network configuration — attach N interfaces per VM with global enable/disable.
- Built-in OS profiles (Ubuntu 22/24, Rocky 9, Debian 12) with local or URL image modes.
- Shared base volumes via `quick-os-volume` — one download, many thin VMs.
- SSH and hosts file generation for easy access and connectivity.
- Graceful validation with actionable error messages.
- Task runner (`Taskfile`) for common operations including OS image management.
- Includes helper scripts for system setup and recovery.

## Prerequisites

### Install Task (Task Runner)

[Task](https://taskfile.dev) is used to run common operations. Install it:

```bash
# Linux (recommended)
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin

# Or via Go
go install github.com/go-task/task/v3/cmd/task@latest

# Or via package manager (Ubuntu/Debian)
sudo snap install task --classic
```

After installation, run `task --list` from the project root to see available commands.

Enable tab completion (zsh):
```bash
echo 'eval "$(task --completion zsh)"' >> ~/.zshrc
```

### Available Tasks

```bash
# Setup
task setup:install-kvm                                  # Install KVM and libvirt
task setup:enable-shared-folders                        # Allow libvirt-qemu to access your files
task setup:disable-shared-folders                       # Remove libvirt-qemu access
task setup:enable-shared-folders-for USER=devx          # Same for a specific user
task setup:disable-shared-folders-for USER=devx         # Remove for a specific user
task setup:install-virtiofsd                            # Install virtiofsd (for virtiofs shared folders)
task setup:check-shared-folders-drivers                 # Check virtiofs and 9p driver availability

# OS Images
task images:list                                        # List all OS images and download status
task images:download:all                                # Download all OS cloud images
task images:download:ubuntu22                           # Download Ubuntu 22.04
task images:download:ubuntu24                           # Download Ubuntu 24.04
task images:download:rocky9                             # Download Rocky Linux 9
task images:download:debian12                           # Download Debian 12
task images:remove:all                                  # Remove all downloaded images
task images:remove:ubuntu22                             # Remove specific image

# Linux Bridge
task bridge:status                                      # Show all bridges status
task bridge:status BRIDGE=br0                           # Show specific bridge
task bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0    # Create a bridge
task bridge:restore                                     # Restore network after bridge removal

# Tools
task tools:clean-vms                                    # Remove all VMs
task tools:clean-networks                               # Remove all KVM networks
task tools:init-cloud-config DIR=./templates            # Create cloud-init user-data template

# KVM Network Info
task net:info NET=neta-loc-1                             # Show network info
task net:test                                            # Run network reader tests
```

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

Each module is located in the [`modules`](./modules) directory:

| Module | Description |
|--------|-------------|
| [`quick-vm`](./modules/quick-vm) | Provision a single VM with dynamic networks, OS profiles, and disk modes |
| [`quick-vms`](./modules/quick-vms) | Provision multiple VMs with shared network config and SSH/hosts generation |
| [`quick-os-volume`](./modules/quick-os-volume) | Create shared base OS volume for thin provisioning across VMs |
| [`quick-networks`](./modules/quick-networks) | Create KVM virtual networks (NAT and bridge) |
| [`quick-kvm-network-reader`](./modules/quick-kvm-network-reader) | Read and expose KVM network info via shell script |
| [`quick-ssh-config`](./modules/quick-ssh-config) | Generate SSH config with usage instructions |
| [`quick-hosts`](./modules/quick-hosts) | Generate `hosts` entries for VMs |

## Examples

The [`examples`](./examples) directory demonstrates how to use the modules:

| Example | Description |
|---------|-------------|
| [`example1-network`](./examples/example1-network) | Create KVM networks (NAT + bridge) |
| [`example2-kvm-network-reader`](./examples/example2-kvm-network-reader) | Read and display network parameters |
| [`example3a-vm`](./examples/example3a-vm) | Single VMs with various network configs (static, DHCP, profile_name) |
| [`example3b-vm`](./examples/example3b-vm) | Single VMs with custom storage and network configs |
| [`example3c-vm`](./examples/example3c-vm) | OS image modes: shared os_volume, standalone os_name, custom os_profile |
| [`example4-vms`](./examples/example4-vms) | Multiple VMs (masters + workers) with quick-vms |
| [`example5-vms`](./examples/example5-vms) | Multiple quick-vms instances sharing one base volume, clone vs backing_store |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/tools/get-os-image.sh` | Download, list, and remove OS cloud images |
| `scripts/tools/init-cloud-config.sh` | Create cloud-init user-data template with SSH key |
| `scripts/tools/clean-all-vms.sh` | Remove all VMs from libvirt |
| `scripts/tools/clean-kvm-network.sh` | Remove all KVM networks |
| `scripts/setup/install-kvm.sh` | Install KVM and libvirt packages |
| `scripts/linux-bridge/show-bridge-status.sh` | Show Linux bridge status and diagnostics |
| `scripts/linux-bridge/create-bridge.sh` | Create a Linux bridge |
| `scripts/linux-bridge/restore-network.sh` | Restore network after bridge removal |

## Documentation

Detailed project structure, module descriptions, and script documentation: [`doc/STRUCTURE.md`](./doc/STRUCTURE.md)

## External Links

- KVM: https://www.linux-kvm.org
- Terraform Libvirt Provider: https://github.com/dmacvicar/terraform-provider-libvirt
- Cloud-Init: https://cloudinit.readthedocs.io/en/latest/
- Task Runner: https://taskfile.dev