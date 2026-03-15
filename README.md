# Quick-Virt

**Quick-Virt** is a collection of Terraform modules and shell scripts designed to simplify the process of creating and managing KVM-based virtual machines (VMs) on Linux for development purposes.
The project was tested and run on **Ubuntu 24.04 LTS**.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## Key Features

- Rapid creation of KVM networks and VMs using Terraform.
- Modular structure to support single VM or multiple node cluster provisioning.
- SSH and hosts file generation for easy access and connectivity.
- Graceful network error handling with actionable validation messages.
- Task runner (`Taskfile`) for common operations.
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

### Available Tasks

```bash
task setup:install-kvm                                  # Install KVM and libvirt
task bridge:status                                      # Show all bridges status
task bridge:status BRIDGE=br0                           # Show specific bridge
task bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0    # Create a bridge
task bridge:restore                                     # Restore network after bridge removal
task tools:clean-vms                                    # Remove all VMs
task tools:clean-networks                               # Remove all KVM networks
task tools:get-ubuntu22                                  # Download Ubuntu 22.04 image
task net:info NET=neta-loc-1                             # Show network info
task net:test                                            # Run network reader tests
```

## Core Module: `quick-vm`

The `quick-vm` module is the foundation of the project. It enables the creation of a **single VM** with flexible network configuration options:

- **Local interface** with **DHCP** or **static IP** support
- **Bridge interface** with **DHCP** or **static IP** support
- Network profile via `profile` (object) or `profile_name` (string — auto-reads from libvirt)

To extract information about available KVM networks (e.g., name, type, address), the module `quick-kvm-network-reader` can be used.

## Multi-VM Setup: `quick-vms`

The `quick-vms` module allows the creation of a **subset of nodes** based on a given configuration. It automates:

- Provisioning of multiple VMs
- SSH configuration generation (`quick-ssh-config`)
- Hosts file generation (`quick-hosts`)

Ensure your cloud-init configuration includes your **public SSH key** to enable passwordless access.

## Modules Overview

Each module is located in the [`modules`](./modules) directory:

| Module | Description |
|--------|-------------|
| [`quick-vm`](./modules/quick-vm) | Provision a single VM with support for user-data, meta-data, and network-config |
| [`quick-vms`](./modules/quick-vms) | Provision multiple VMs based on a configuration file |
| [`quick-networks`](./modules/quick-networks) | Create KVM virtual networks |
| [`quick-kvm-network-reader`](./modules/quick-kvm-network-reader) | Read and expose KVM network info via script |
| [`quick-kvm-storage-pool-reader`](./modules/quick-kvm-storage-pool-reader) | Read KVM storage pool info |
| [`quick-ssh-config`](./modules/quick-ssh-config) | Generate SSH config for easy access to VMs |
| [`quick-hosts`](./modules/quick-hosts) | Generate `hosts` entries for VMs |

Each module contains a `variables.tf` describing input parameters and a `main.tf` with logic. Outputs are defined in `outputs.tf` (if applicable).

## Examples

The [`examples`](./examples) directory demonstrates how to use the modules:

| Example | Description |
|---------|-------------|
| [`example1-network`](./examples/example1-network) | Create a KVM network |
| [`example2-kvm-network-reader`](./examples/example2-kvm-network-reader) | Read and display network parameters |
| [`example3a-vm`](./examples/example3a-vm) | Single VM creation with network profile via reader |
| [`example3b-vm`](./examples/example3b-vm) | Single VM with static IP and profile_name |
| [`example4-vms`](./examples/example4-vms) | Multiple VMs, with SSH and hosts config |

## Documentation

Detailed project structure, module descriptions, and script documentation: [`doc/STRUCTURE.md`](./doc/STRUCTURE.md)

## External Links

- KVM: https://www.linux-kvm.org
- Terraform Libvirt Provider: https://github.com/dmacvicar/terraform-provider-libvirt
- Cloud-Init: https://cloudinit.readthedocs.io/en/latest/
- Task Runner: https://taskfile.dev