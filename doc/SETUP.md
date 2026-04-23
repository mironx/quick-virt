# Setup

## Install Task (Task Runner)

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

## Available Tasks

Tasks are listed in the typical order you would run them — from host preparation, through image download, to creating KVM networks, the VM lifecycle, and cleanup.

### 1. Host preparation (one-time)

| # | Task | What it does | When to run |
|---|------|--------------|-------------|
| 1 | `task setup:install-kvm` | Installs KVM, libvirt, and helper packages | Once, on a fresh host. Required before anything else. |
| 2 | `task setup:install-virtiofsd` | Installs `virtiofsd` daemon | Only if you plan to use `fs_type = "virtiofs"` shared folders (recommended driver). |
| 3 | `task setup:check-shared-folders-drivers` | Verifies `virtiofs` and `9p` driver availability on the host | After step 2 — quick sanity check before using shared folders. |
| 4 | `task setup:enable-shared-folders` | Adds `libvirt-qemu` to your user's group so QEMU can read host files | Required before mounting host directories into VMs via shared folders. |
| 5 | `task setup:enable-shared-folders-for USER=devx` | Same as above but for a specific user | When configuring shared folders on behalf of another user account. |
| 6 | `task setup:disable-shared-folders` | Removes `libvirt-qemu` from your group | Rollback of step 4. |
| 7 | `task setup:disable-shared-folders-for USER=devx` | Removes access for a specific user | Rollback of step 5. |
| 8 | `task setup:install-nfs-server` | Installs and enables the NFS server (`nfs-kernel-server` on Debian/Ubuntu, `nfs-utils` on Rocky) | Required once before using VMs with the `nfs_mounts` variable. |
| 9 | `task setup:configure-nfs-export DIR=… CIDR=…` | Creates the directory, sets ownership, and adds an idempotent entry to `/etc/exports` | After step 8 — declares **what** gets exported and **who** can mount it. See parameters below. |

**`setup:configure-nfs-export` parameters:**

| Name | Required | Default | Example |
|------|:---:|---------|---------|
| `DIR` | ✓ | — | `/home/devx/vm-shares` |
| `CIDR` | ✓ | — | `192.168.100.0/24` |
| `OPTIONS` | — | `rw,sync,no_subtree_check,no_root_squash` | `ro,sync,no_subtree_check` |
| `OWNER` | — | caller's `user:group` (or `SUDO_USER`) | `devx:devx` |

Idempotent — an existing entry for the same `DIR` is replaced. Runs `exportfs -ra` and prints the active exports.

### 2. OS images

| # | Task | What it does | When to run |
|---|------|--------------|-------------|
| 1 | `task images:list` | Lists all supported OS images and their download status | First — to see what's missing. |
| 2 | `task images:download:all` | Downloads every supported OS cloud image | When you want every image available locally. |
| 3 | `task images:download:ubuntu22` | Downloads Ubuntu 22.04 cloud image | Before provisioning a VM with `os_name = "ubuntu_22"` (local mode). |
| 4 | `task images:download:ubuntu24` | Downloads Ubuntu 24.04 cloud image | Before provisioning a VM with `os_name = "ubuntu_24"`. |
| 5 | `task images:download:rocky9` | Downloads Rocky Linux 9 cloud image | Before provisioning a VM with `os_name = "rocky_9"`. |
| 6 | `task images:download:debian12` | Downloads Debian 12 cloud image | Before provisioning a VM with `os_name = "debian_12"`. |
| 7 | `task images:remove:ubuntu22` | Removes a single downloaded image | When you want to force a re-download or free disk space. |
| 8 | `task images:remove:all` | Removes all downloaded images | Full cleanup of the local image cache. |

### 3. Create KVM networks (Terraform — one-time per environment)

The `quick-vm` / `quick-vms` modules attach VMs to libvirt networks by name (`profile_name = "qvexample-neta-loc-1"`). **These networks must exist before you apply any VM example** — otherwise `terraform apply` fails with *"network not found"*.

Creating networks is a Terraform operation, done via the [`quick-networks`](../modules/quick-networks) module. Two paths:

**Scaffold a project in your own directory (recommended):**

```bash
task scaffold:init-networks DIR=./my-networks
cd ./my-networks
terraform init
terraform apply
```

`scaffold:init-networks` writes `main.tf`, `variables.tf`, and `networks.auto.tfvars` pinned to the currently-installed `quick-virt` version. The generated `networks.auto.tfvars` ships with one NAT network active and a second NAT + bridge commented out — edit to taste.

**Or apply the ready-made example in-repo:**

```bash
cd examples/example1-network
terraform init
terraform apply -var-file=networks.auto.tfvars
```

See [`doc/USAGE.md`](./USAGE.md#quick-networks--kvm-networks) for the full input schema.

Useful helpers once networks exist:

| Task | What it does |
|------|--------------|
| `task net:info NET=qvexample-neta-loc-1` | Print resolved parameters (CIDR, gateway, DHCP range) of an existing libvirt network |
| `task tools:clean-networks` | Destroy **every** libvirt network on the host (emergency cleanup) |

### 4. Linux bridge (only for bridge-mode networks)

| # | Task | What it does | When to run |
|---|------|--------------|-------------|
| 1 | `task bridge:status` | Shows the status of all Linux bridges | Diagnostics — before or after creating a bridge. |
| 2 | `task bridge:status BRIDGE=br0` | Shows status for a specific bridge | Focused diagnostics for one bridge. |
| 3 | `task bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0` | Creates a Linux bridge tied to a physical interface | Required once, before using bridge-mode networks in Terraform. |
| 4 | `task bridge:restore` | Restores host networking after a bridge is torn down | Recovery — if the bridge broke your connectivity. |

### 5. KVM network info

| # | Task | What it does | When to run |
|---|------|--------------|-------------|
| 1 | `task net:info NET=neta-loc-1` | Prints parameters (CIDR, DHCP range, etc.) for a libvirt network | When you need the real values of an existing network. |
| 2 | `task net:test` | Runs the network reader smoke tests | After changing the `quick-kvm-network-reader` module. |

### 6. Cleanup tools

| # | Task | What it does | When to run |
|---|------|--------------|-------------|
| 1 | `task tools:clean-vms` | Destroys every libvirt VM on the host | Emergency cleanup when `terraform destroy` can't recover the state. |
| 2 | `task tools:clean-networks` | Destroys every libvirt network on the host | Same — for orphan networks. |
| 3 | `task scaffold:init-cloud-config DIR=./templates` | Creates a cloud-init `user-data` template with your SSH key | Once per new example — bootstraps the cloud-init template. |
| 4 | `task scaffold:init-networks DIR=./my-networks` | Scaffolds a Terraform project for KVM networks (pinned to installed version) | Once per environment — see step 3 of this guide. |

## Scripts

Shell scripts that back the tasks (you can also invoke them directly):

| Script | Description |
|--------|-------------|
| `scripts/tools/get-os-image.sh` | Download, list, and remove OS cloud images |
| `scripts/scaffold/init-cloud-config.sh` | Create cloud-init user-data template with SSH key |
| `scripts/scaffold/init-networks.sh` | Scaffold a Terraform project for KVM networks |
| `scripts/tools/clean-all-vms.sh` | Remove all VMs from libvirt |
| `scripts/tools/clean-kvm-network.sh` | Remove all KVM networks |
| `scripts/tools/check-shared-folders-drivers.sh` | Check `virtiofs` and `9p` driver availability |
| `scripts/setup/install-kvm.sh` | Install KVM and libvirt packages |
| `scripts/linux-bridge/show-bridge-status.sh` | Show Linux bridge status and diagnostics |
| `scripts/linux-bridge/create-bridge.sh` | Create a Linux bridge |
| `scripts/linux-bridge/restore-network.sh` | Restore network after bridge removal |
