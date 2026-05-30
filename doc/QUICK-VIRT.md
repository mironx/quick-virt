# `quick-virt` — Command Reference

Complete reference for every `quick-virt` command, with at least one example each.

`quick-virt` is a thin wrapper around the [Task](https://taskfile.dev) runner — every command maps to a task in `Taskfile.yml`, which in turn calls a script under `scripts/`.

- **Installed via `install.sh`:** use `quick-virt <command>` from anywhere.
- **From a cloned repo:** use `task <command>` from the repo root. The two are interchangeable; this page uses the `quick-virt` form.

```bash
quick-virt help        # grouped quick reference with examples (or just: quick-virt)
quick-virt --list      # full, flat list of every command with its description
quick-virt <group>:<action> [VAR=value ...]
```

`quick-virt help` (also shown when you run `quick-virt` with no arguments) prints a colored, grouped cheat-sheet — the same commands as this page, condensed. This document is the long-form reference.

Several commands run privileged steps (package install, network, libvirt) and call `sudo` internally — you'll be prompted for your password even though you don't type `sudo` yourself.

**Table of contents**

- [Self-management (`self:*`)](#self-management)
- [Host setup (`setup:*`)](#host-setup)
- [OS images (`images:*`)](#os-images)
- [Linux bridge (`bridge:*`)](#linux-bridge)
- [KVM network info (`net:*`)](#kvm-network-info)
- [Scaffolding (`scaffold:*`)](#scaffolding)
- [Cleanup tools (`tools:*`)](#cleanup-tools)
- [Parameter reference](#parameter-reference)

---

## Self-management

Manage the `quick-virt` installation itself (only meaningful when installed via `install.sh`).

> [!NOTE]
> **Automatic update check.** Every `quick-virt` command (except `self:*`) prints a one-line notice on stderr when a newer release exists — e.g. `[quick-virt] Update available: v0.1.0 → v0.2.4. Run: quick-virt self:update`. It is offline-instant (it reads a cache refreshed in the background at most once per 24h) and never delays or blocks your command. Clone users (running `task` directly) don't get this notice — use `self:check-update` instead.

Environment variables that tune or disable the automatic check:

| Env var | Effect |
|---------|--------|
| `QV_NO_UPDATE_CHECK=1` | Disable the notice entirely |
| `QV_UPDATE_TTL=<sec>` | Seconds between background GitHub checks (default `86400`) |
| `QV_NAG_TTL=<sec>` | Seconds between repeated notices (default `86400`) |

### `self:version`
Show the installed version (reads `.version`). Prints `unknown` when run from a cloned repo.
```bash
quick-virt self:version
# v0.1.8
```

### `self:check-update`
Explicitly query GitHub and report installed vs latest (synchronous; also refreshes the cache). This is the manual equivalent of the automatic notice — and the only way clone users get it.
```bash
quick-virt self:check-update
# installed: v0.1.0
# latest   : v0.2.4
# [update] newer version available — run: quick-virt self:update
```

### `self:where`
Show where `quick-virt` lives: prefix, Taskfile path, wrapper binary, and version.
```bash
quick-virt self:where
# prefix   : /home/devx/.local/share/quick-virt
# taskfile : /home/devx/.local/share/quick-virt/Taskfile.yml
# binary   : /home/devx/.local/bin/quick-virt
# version  : v0.1.8
```

### `self:update`
Re-run the installer to fetch the latest tag. Override the version with `QV_VERSION`.
```bash
quick-virt self:update
QV_VERSION=v0.1.8 quick-virt self:update   # pin a specific tag
QV_VERSION=main   quick-virt self:update   # track development head
```

> [!TIP]
> Updating overwrites the Taskfile, scripts, and the `quick-virt` wrapper in place. Your VMs, networks, images, and Terraform projects are untouched. Confirm afterwards with `quick-virt self:version`.

| Goal | Command |
|------|---------|
| 🟢 Update to the **latest tag** | `quick-virt self:update` |
| 📌 Update to a **specific version** | `QV_VERSION=v0.1.8 quick-virt self:update` |
| 🧪 Track the **development head** | `QV_VERSION=main quick-virt self:update` |
| 🔁 Update **without the CLI** | Re-run `install.sh` (see [README → Quick Install](../README.md#quick-install-no-clone-required)) |

### `self:uninstall`
Remove the installation (the install prefix + the `quick-virt` wrapper).
```bash
quick-virt self:uninstall
# [ok] quick-virt uninstalled (removed /home/devx/.local/share/quick-virt and /home/devx/.local/bin/quick-virt)
```

---

## Host setup

One-time host preparation: KVM/libvirt, shared folders, and NFS.

### `setup:install-kvm`
Install KVM, libvirt, and related packages. Run once on a fresh host before anything else.
```bash
quick-virt setup:install-kvm
```

### `setup:install-virtiofsd`
Install the `virtiofsd` daemon (needed for `fs_type = "virtiofs"` shared folders — the recommended driver).
```bash
quick-virt setup:install-virtiofsd
```

### `setup:check-shared-folders-drivers`
Check `virtiofs` and `9p` driver availability on the host (read-only diagnostics).
```bash
quick-virt setup:check-shared-folders-drivers
```

### `setup:enable-shared-folders`
Add `libvirt-qemu` to **your** user's group so QEMU can read your files (required before mounting host dirs into VMs). Restart libvirtd afterwards.
```bash
quick-virt setup:enable-shared-folders
sudo systemctl restart libvirtd
```

### `setup:disable-shared-folders`
Rollback of the above — remove `libvirt-qemu` from your group.
```bash
quick-virt setup:disable-shared-folders
```

### `setup:enable-shared-folders-for` — requires `USER`
Same as `enable-shared-folders` but for a specific user account.
```bash
quick-virt setup:enable-shared-folders-for USER=devx
```

### `setup:disable-shared-folders-for` — requires `USER`
Rollback for a specific user.
```bash
quick-virt setup:disable-shared-folders-for USER=devx
```

### `setup:install-nfs-server`
Install and enable the NFS server (`nfs-kernel-server` on Debian/Ubuntu, `nfs-utils` on Rocky). Required once before using VMs with `nfs_mounts`.
```bash
quick-virt setup:install-nfs-server
```

### `setup:configure-nfs-export` — requires `DIR`, `CIDR`
Create the directory, set ownership, and add an idempotent `/etc/exports` entry. Optional `OPTIONS` and `OWNER`.
```bash
# Minimal — defaults: OPTIONS=rw,sync,no_subtree_check,no_root_squash, OWNER=caller's user:group
quick-virt setup:configure-nfs-export DIR=/home/devx/vm-shares CIDR=192.168.100.0/24

# Read-only export, explicit owner
quick-virt setup:configure-nfs-export \
  DIR=/home/devx/vm-shares \
  CIDR=192.168.100.0/24 \
  OPTIONS=ro,sync,no_subtree_check \
  OWNER=devx:devx
```
`DIR` must be an absolute path. Re-running for the same `DIR` replaces the existing entry.

---

## OS images

Download / list / remove cloud images into `/var/lib/libvirt/images`. Supported: `ubuntu_22`, `ubuntu_24`, `rocky_9`, `debian_12`.

### `images:list`
List all supported images and their download status (with size).
```bash
quick-virt images:list
```

### `images:download:all`
Download every supported cloud image.
```bash
quick-virt images:download:all
```

### `images:download:ubuntu22` · `:ubuntu24` · `:rocky9` · `:debian12`
Download a single image. Run before provisioning a VM with the matching `os_name` in local mode.
```bash
quick-virt images:download:ubuntu22    # Ubuntu 22.04
quick-virt images:download:ubuntu24    # Ubuntu 24.04
quick-virt images:download:rocky9      # Rocky Linux 9
quick-virt images:download:debian12    # Debian 12
```

### `images:remove:all`
Remove all downloaded images (clear the local cache).
```bash
quick-virt images:remove:all
```

### `images:remove:ubuntu22` · `:ubuntu24` · `:rocky9` · `:debian12`
Remove a single image (e.g. to force a re-download or free disk space).
```bash
quick-virt images:remove:ubuntu22
quick-virt images:remove:ubuntu24
quick-virt images:remove:rocky9
quick-virt images:remove:debian12
```

---

## Linux bridge

Only needed for **bridge-mode** networks. Uses NetworkManager (`nmcli`). These commands modify host networking and may briefly drop connectivity — be careful on remote hosts.

### `bridge:status`
Show status and recommendations for all bridges, or a single one via `BRIDGE`.
```bash
quick-virt bridge:status              # all bridges
quick-virt bridge:status BRIDGE=br0   # one bridge
```

### `bridge:create` — requires `PHYS_IF`, `BRIDGE_NAME`
Create a bridge tied to a physical interface (clones its MAC, attaches it as slave, DHCP IPv4). Run once before using bridge-mode networks.
```bash
quick-virt bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0
```
Find your interface name with `ip -br link`.

### `bridge:restore` — requires `PHYS_IF`, `BRIDGE_NAME`
Tear down the bridge and its slave, then recreate a plain DHCP connection on the physical interface. Recovery path if a bridge broke connectivity.
```bash
quick-virt bridge:restore PHYS_IF=enp0s31f6 BRIDGE_NAME=br0
```

---

## KVM network info

### `net:info` — requires `NET`
Print the resolved parameters (CIDR, gateway, DHCP range, …) of an existing libvirt network.
```bash
quick-virt net:info NET=qvexample-neta-loc-1
```

### `net:test`
Run the smoke tests for the `kvm-net-info.sh` reader. Useful after changing the `quick-kvm-network-reader` module.
```bash
quick-virt net:test
```

---

## Scaffolding

Bootstrap boilerplate configs into a target directory.

### `scaffold:init-cloud-config` — requires `DIR`
Create a cloud-init `user-data.tmpl`, auto-injecting your SSH public key from `~/.ssh/` (placeholder if none found). Skips if the file already exists.
```bash
quick-virt scaffold:init-cloud-config DIR=./templates
quick-virt scaffold:init-cloud-config DIR=.            # current directory
```
Output: `<DIR>/user-data.tmpl`.

### `scaffold:init-networks` — optional `DIR`, `REF`
Scaffold a Terraform project (`main.tf`, `variables.tf`, `networks.auto.tfvars`) for KVM networks via the `quick-networks` module. `DIR` defaults to `.`; `REF` (module git ref) defaults to the installed version, else `main`. Existing files are not overwritten.
```bash
quick-virt scaffold:init-networks                       # into current dir, installed version
quick-virt scaffold:init-networks DIR=./my-networks     # into a subdir
quick-virt scaffold:init-networks DIR=./my-networks REF=v0.1.8   # pin module ref

# Then:
cd ./my-networks
terraform init
terraform apply
```

---

## Cleanup tools

Emergency cleanup when Terraform state can't recover. **Destructive — affects every VM / network on the host.**

### `tools:clean-vms`
Destroy and undefine **all** libvirt VMs.
```bash
quick-virt tools:clean-vms
```

### `tools:clean-networks`
Destroy **all** libvirt/KVM networks.
```bash
quick-virt tools:clean-networks
```

---

## Parameter reference

Variables are passed as `NAME=value` after the command (Task syntax).

| Command | Required | Optional | Notes |
|---------|----------|----------|-------|
| `setup:enable-shared-folders-for` | `USER` | — | target username |
| `setup:disable-shared-folders-for` | `USER` | — | target username |
| `setup:configure-nfs-export` | `DIR`, `CIDR` | `OPTIONS`, `OWNER` | `DIR` absolute; defaults: `OPTIONS=rw,sync,no_subtree_check,no_root_squash`, `OWNER=` caller's `user:group` |
| `bridge:status` | — | `BRIDGE` | omit `BRIDGE` for all bridges |
| `bridge:create` | `PHYS_IF`, `BRIDGE_NAME` | — | physical iface + bridge name |
| `bridge:restore` | `PHYS_IF`, `BRIDGE_NAME` | — | physical iface + bridge name |
| `net:info` | `NET` | — | libvirt network name |
| `scaffold:init-cloud-config` | `DIR` | — | output dir for `user-data.tmpl` |
| `scaffold:init-networks` | — | `DIR`, `REF` | `DIR` default `.`; `REF` default installed version / `main` |

`QV_VERSION` (environment variable, not a task var) overrides the version for `self:update`:
```bash
QV_VERSION=v0.1.8 quick-virt self:update
```

---

See also: [`doc/SETUP.md`](./SETUP.md) for the recommended **ordered** workflow (host → images → networks → VMs → cleanup), and [`doc/USAGE.md`](./USAGE.md) for the Terraform module reference.