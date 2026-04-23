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

## Quick Install (no clone required)

Install the `quick-virt` CLI — Taskfile + helper scripts — without cloning the repo. It pulls the **latest tag** by default:

```bash
curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | bash
```

Pin a specific version, or track `main`:

```bash
# Pinned tag:
curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | QV_VERSION=v0.1.8 bash

# Development head:
curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | QV_VERSION=main bash
```

The installer places:

| Location | What |
|----------|------|
| `~/.local/share/quick-virt/` | `Taskfile.yml` + `scripts/` + `modules/quick-kvm-network-reader/scripts/` |
| `~/.local/bin/quick-virt` | Wrapper that runs `task -t ~/.local/share/quick-virt/Taskfile.yml "$@"` |

**Prerequisites:** `curl`, `tar`, and [Task](https://taskfile.dev). The installer will warn if `task` isn't on your PATH.

**Usage:**

```bash
quick-virt --list                          # list all available tasks
quick-virt setup:install-kvm               # install KVM + libvirt
quick-virt setup:install-nfs-server        # install NFS server
quick-virt images:download:ubuntu22        # download Ubuntu 22.04 cloud image
```

**Management:**

```bash
quick-virt self:version       # show installed version
quick-virt self:update        # re-install the latest tag
quick-virt self:uninstall     # remove
```

The full ordered task reference is in [`doc/SETUP.md`](./doc/SETUP.md).

## Getting Started

End-to-end, going from zero to a running VM takes five steps:

1. **Install the CLI** — see *Quick Install* above (or clone the repo).
2. **Install the KVM host stack** — `quick-virt setup:install-kvm` (once per host).
3. **Download an OS image** — `quick-virt images:download:ubuntu22` (or `…:ubuntu24`, `…:rocky9`, `…:debian12`).
4. **Create KVM networks** — the VM modules reference libvirt networks by name (`profile_name = "qvexample-neta-loc-1"`). You must create them first with the `quick-networks` module, or `terraform apply` will fail with *"network not found"*. The quickest path:
   ```bash
   cd examples/example1-network
   terraform init
   terraform apply -var-file=networks.auto.tfvars
   ```
   Or write your own root module using [`quick-networks`](./modules/quick-networks) — see [`doc/USAGE.md`](./doc/USAGE.md#quick-networks--kvm-networks).
5. **Create VMs** — apply one of the `example3*` / `example4-vms` / `example5-vms` modules, or roll your own with `quick-vm` / `quick-vms`.

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