# Setup v3 — from zero to a running VM

> **Status: DRAFT** — outline only. Each section will be expanded with commands,
> expected output, and troubleshooting. Steps 1–7 are the required path,
> 8–10 are optional features, 11–12 close the loop, 13 is the safety net.

**What is quick-virt?** A toolkit for spinning up KVM virtual machines on a Linux
workstation for development:

- a set of **Terraform modules** (`quick-vm`, `quick-vms`, `quick-networks`, …)
  that describe networks, VMs, and VM sets declaratively,
- a thin **CLI** (`quick-virt`) wrapping the [Task](https://taskfile.dev) runner —
  host setup, OS image management, scaffolding, and recovery tools,
- **generators** that turn applied infrastructure into files you actually use:
  ssh-config, hosts file, Ansible inventory (`.qv-access/`), and resource-limit
  profiles (`.qv-limits/`).

## Contents

- [1. Host requirements & tooling](#1-host-requirements--tooling)
- [2. Install the quick-virt CLI](#2-install-the-quick-virt-cli)
- [3. Install the KVM host stack](#3-install-the-kvm-host-stack)
- [4. Storage pool check](#4-storage-pool-check)
- [5. Download OS cloud images](#5-download-os-cloud-images)
- [6. (Optional) Linux bridge — decide BEFORE creating networks](#6-optional-linux-bridge--decide-before-creating-networks)
- [7. Create KVM networks](#7-create-kvm-networks)
- [8. (Optional) NFS server](#8-optional-nfs-server)
- [9. (Optional) Shared folders](#9-optional-shared-folders)
- [10. SSH key](#10-ssh-key)
- [11. Run the first VM](#11-run-the-first-vm)
- [12. Working with generated files](#12-working-with-generated-files)
- [13. Troubleshooting / recovery](#13-troubleshooting--recovery)

## 1. Host requirements & tooling

- Linux host — tested on **Ubuntu 24.04 LTS** (installer scripts are apt-based)
- CPU virtualization enabled in BIOS/UEFI (Intel VT-x / AMD-V)
  - quick check: `egrep -c '(vmx|svm)' /proc/cpuinfo` → must be > 0
  - full check (after step 3): `kvm-ok`
- Enough headroom: RAM and disk for the VMs you plan (base images ~600 MB each,
  default VM disk 20 GiB thin)
- **Terraform** (>= 1.3; >= 1.9 recommended) — not covered by the installer:
  - official apt repo / tenv / manual binary — TBD which to recommend
  - verify: `terraform version`
  - provider `dmacvicar/libvirt ~> 0.9` is pulled automatically by `terraform init`
- Internet access — GitHub (installer), cloud-image mirrors (images)

## 2. Install the quick-virt CLI

- Install the Task runner first — quick-virt is a wrapper around it:
  - `sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin`
- Install quick-virt (no clone required):
  - `curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | bash`
  - pin a version with `QV_VERSION=vX.Y.Z`, track dev head with `QV_VERSION=main`
- Make sure `~/.local/bin` is on `PATH`
- Verify: `quick-virt self:version`, `quick-virt --list`
- Alternative: clone the repo and use `task` directly from the checkout

## 3. Install the KVM host stack

- `quick-virt setup:install-kvm`
  - installs qemu-kvm, libvirt, cloud-image tools, and module helpers (jq, xmllint, ipcalc)
  - adds your user to the `libvirt` and `kvm` groups
  - enables and starts `libvirtd`
- **Log out and back in** (or `newgrp libvirt`) so the group change takes effect
- Verify:
  - `virsh -c qemu:///system list --all` works **without sudo**
  - `kvm-ok` reports KVM acceleration can be used

## 4. Storage pool check

- quick-vm places disks in a libvirt **storage pool** — `default` unless you set
  `storage_pool`; on some fresh installs the `default` pool is not defined
- Check: `virsh pool-list --all` → `default` should be listed, active, autostart
- If missing, create it (proposal — the standard dir pool):
  - `virsh pool-define-as default dir --target /var/lib/libvirt/images`
  - `virsh pool-build default && virsh pool-start default && virsh pool-autostart default`
- TBD: decide whether `setup:install-kvm` should do this automatically
  (idempotent check) instead of documenting a manual step
- TBD: short note on using a custom pool on a bigger disk
  (`pool-define-as vms dir --target /data/vms` + `storage_pool = "vms"` in HCL)

## 5. Download OS cloud images

- One image: `quick-virt images:download:ubuntu22` (also: `ubuntu24`, `rocky9`, `debian12`)
- Everything: `quick-virt images:download:all`
- Verify: `quick-virt images:list` — status `downloaded` next to the image you need
- Images land in `/var/lib/libvirt/images/*.qcow2.base`

## 6. (Optional) Linux bridge — decide BEFORE creating networks

- Needed only when VMs should be reachable from your LAN; NAT-only setups skip this
- **Why this step comes before networks:** a `mode = "bridge"` libvirt network
  points at a host bridge by name — the decision (and the bridge itself) has to
  exist before you apply the network definitions in step 7
- Create: `quick-virt bridge:create PHYS_IF=<nic> BRIDGE_NAME=br0`
  - warning: reconfigures host networking — risky over remote/SSH sessions
- Check: `quick-virt bridge:status`
- Rollback: `quick-virt bridge:restore PHYS_IF=<nic> BRIDGE_NAME=br0`

## 7. Create KVM networks

- VM modules reference libvirt networks **by name** — the networks must exist first,
  otherwise `terraform apply` fails with *"network not found"*
- Fastest path — ready-made root:
  - `cd examples/prerequisites/01-networks-nat-bridge`
  - `terraform init && terraform apply -var-file=networks.tfvars` (or `./tf-apply.sh`)
- Alternative — scaffold your own project:
  - `quick-virt scaffold:init-networks DIR=./my-networks` then edit + apply
- **No bridge on the host, but the tfvars contains a bridge network?** Three options:
  - **A (recommended):** go back to step 6 and create `br0` first, then apply everything
  - **B:** comment the bridge network out of `networks.tfvars` and apply only the
    NAT networks — add it back later when the bridge exists
  - **C:** apply it anyway — libvirt will happily *define* a bridge-mode network
    that points at a nonexistent `br0`; the failure surfaces **later**, when a VM
    attached to it starts (`Cannot get interface MTU on 'br0'`). Workable only if
    you also keep that network disabled on the VM side
    (`kvm_networks = { "...net-bridge" = { enabled = false } }`)
  - TBD: expand into a short decision table with exact error messages
- Verify: `virsh net-list --all` shows the networks as active
- Inspect details anytime: `quick-virt net:info NET=<name>`

## 8. (Optional) NFS server — for `nfs_mounts`

- Install: `quick-virt setup:install-nfs-server`
- Export a directory to the VM network:
  - `quick-virt setup:configure-nfs-export DIR=/home/$USER/vm-shares CIDR=192.168.200.0/24`
  - the NAT gateway IP of the network **is** the host address VMs mount from
- Verify: `showmount -e localhost`

## 9. (Optional) Shared folders — for `shared_folders` (virtiofs / 9p)

- Check driver availability: `quick-virt setup:check-shared-folders-drivers`
- Install virtiofsd if missing: `quick-virt setup:install-virtiofsd`
- Grant qemu access to your files: `quick-virt setup:enable-shared-folders`
  - note: adds the `libvirt-qemu` user to **your** group — qemu can then read
    group-readable files in your home; undo with `setup:disable-shared-folders`

## 10. SSH key (for examples that inject one)

- Ensure `~/.ssh/id_rsa.pub` exists (`ssh-keygen` if not)
- Examples 03+ read it with `file("~/.ssh/id_rsa.pub")` and put it in cloud-init

## 11. Run the first VM

- Pick an example (see [`examples/README.md`](../examples/README.md)):
  - simplest start: `examples/02a-vm-network-variants`
- `terraform init && terraform apply`
- Verify the VM:
  - `virsh list` — VM running
  - `virsh console <name>` — login with the demo user/password from tfvars
  - or SSH to the static IP from the example
- Tear down: `terraform destroy` in the same directory

## 12. Working with generated files

After `terraform apply`, the access and limit modules render ready-to-use files
under your project root. Draft of what to cover:

### 12.1 SSH access (`.qv-access/ssh-config`)

- Generated by `quick-access-ssh` from the VMs' group info
- Use it without touching your global SSH config:
  - `ssh -F .qv-access/ssh-config <vm-name>`
  - secondary networks are reachable via suffixed aliases (e.g. `<vm-name>.br`)
- TBD: optional `Include` line in `~/.ssh/config` for permanent setups

### 12.2 Hosts file (`.qv-access/hosts`)

- Generated by `quick-access-hosts` — `/etc/hosts`-style block for all VMs
- Use ad hoc (`getent`-less lookup): `grep <vm> .qv-access/hosts`
- Or append to the system file: `sudo tee -a /etc/hosts < .qv-access/hosts`
  - TBD: recommend a marker-block pattern so re-applies replace, not duplicate

### 12.3 Ansible inventory (`.qv-access/inventory.ini`)

- Generated by `quick-access-ansible` — groups preserved, `[all:vars]` carries
  SSH user/key/become settings
- Smoke test: `ansible -i .qv-access/inventory.ini all -m ping`
- Custom groups (supersets, merged clusters) — see `examples/06-vms-access-helpers`

### 12.4 Resource limits (`.qv-limits/`) — brief, details get their own section

- Generated by the `quick-throttle*` modules: per-axis profile files
  (`<prefix>-{cpu,disk,network}-<name>.ini`), a mapping file
  (`<prefix>-throttle.ini`), and runner scripts
- Workflow in one breath: edit the mapping file (assign profiles to VMs) →
  `bash .qv-limits/qv-throttle.apply.sh .qv-limits/<prefix>-throttle.ini` →
  `...clear.sh` to undo
- Full walkthrough: `examples/05-vms-throttle-limits` + USAGE.md (dedicated
  section TBD — keep this one short)

### 12.5 Scaffolding generators (inputs, not outputs)

- `quick-virt scaffold:init-networks DIR=<dir>` — bootstrap a networks project
  (used in step 7)
- `quick-virt scaffold:init-cloud-config DIR=<dir>` — bootstrap a cloud-init
  `user-data.tmpl` to customize users/packages for your own VMs
- TBD: verify this list stays in sync with `quick-virt --list` output

## 13. Troubleshooting / recovery (TBD — expand)

- *"network not found"* → step 7 not done, or network name typo
- `Cannot get interface MTU on 'br0'` → VM attached to a bridge network whose
  bridge does not exist → step 6 (or option B/C in step 7)
- `virsh` needs sudo → group change not active yet (re-login, step 3)
- permission denied on `/dev/kvm` → user not in `kvm` group / VT-x disabled
- disk create fails / pool errors → `default` storage pool missing (step 4)
- stale/broken VM definitions → emergency reset: `quick-virt tools:clean-vms`
  - **warning: destructive** — removes ALL VM definitions *and* network
    definitions (by design, it is a recovery tool); re-apply step 7 afterwards
- networks only: `quick-virt tools:clean-networks`
- keep the CLI fresh: `quick-virt self:check-update` / `self:update`
