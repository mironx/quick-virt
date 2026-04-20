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

## Setup

See [`doc/SETUP.md`](./doc/SETUP.md) for Task runner installation, ordered task reference, and helper scripts.

## Modules and Examples

See [`doc/MODULES.md`](./doc/MODULES.md) for module descriptions, built-in OS profiles, and example walkthroughs.

## Documentation

- [`doc/SETUP.md`](./doc/SETUP.md) — Task runner installation, available tasks, and helper scripts
- [`doc/MODULES.md`](./doc/MODULES.md) — modules, built-in OS profiles, and example walkthroughs
- [`doc/USAGE.md`](./doc/USAGE.md) — Terraform-style module reference and feature deep dives (shared folders, OS profiles, etc.)
- [`doc/STRUCTURE.md`](./doc/STRUCTURE.md) — project structure and script documentation

## External Links

- KVM: https://www.linux-kvm.org
- Terraform Libvirt Provider: https://github.com/dmacvicar/terraform-provider-libvirt
- Cloud-Init: https://cloudinit.readthedocs.io/en/latest/
- Task Runner: https://taskfile.dev