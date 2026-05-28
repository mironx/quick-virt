# Usage Guide

End-to-end reference for the `quick-virt` Terraform modules with working examples.

> **Note on file name:** I went with `USAGE.md` (singular, matches the common convention — cf. GitHub's `LICENSE`, `README`, `CHANGELOG`). If you prefer `USAGES.md`, just rename the file and update the links.

## Table of Contents

- [Module reference](#module-reference)
  - [`quick-networks` — KVM networks](#quick-networks--kvm-networks)
  - [`quick-os-volume` — shared base OS image](#quick-os-volume--shared-base-os-image)
  - [`quick-vm` — single VM](#quick-vm--single-vm)
  - [`quick-vms` — multiple VMs (sets)](#quick-vms--multiple-vms-sets)
  - [`quick-kvm-network-reader` — read existing network](#quick-kvm-network-reader--read-existing-network)
  - [Access helpers (`.qv-access/`)](#access-helpers-qv-access)
- [Feature deep dives](#feature-deep-dives)
  - [OS profiles (built-in vs custom)](#os-profiles-built-in-vs-custom)
  - [Shared base volume (`os_volume`)](#shared-base-volume-os_volume)
  - [Disk modes (`backing_store` vs `clone`)](#disk-modes-backing_store-vs-clone)
  - [Image modes (`local` vs `url`)](#image-modes-local-vs-url)
  - [Networks (static, DHCP, profile_name)](#networks-static-dhcp-profile_name)
  - [Global network on/off (`kvm-networks`)](#global-network-onoff-kvm-networks)
  - [Shared folders (virtiofs vs 9p)](#shared-folders-virtiofs-vs-9p)
  - [NFS mounts (`nfs_mounts`)](#nfs-mounts-nfs_mounts)
  - [Cloud-init hooks (`run_before`, `run_after`, `user_data_after`)](#cloud-init-hooks-run_before-run_after-user_data_after)
  - [Memory backing](#memory-backing)
  - [Resource limits — CPU, I/O & network throttling](#resource-limits--cpu-io--network-throttling)

---

## Module reference

> **Module source.** The examples below reference the modules directly from GitHub:
>
> ```hcl
> source = "git::https://github.com/mironx/quick-virt.git//modules/<module-name>?ref=main"
> ```
>
> Pin to a specific release by replacing `ref=main` with a tag (e.g. `ref=v1.0.0`) or commit SHA. When developing locally in a fork of this repo, use a relative path instead (e.g. `source = "../../modules/quick-vm"`) — see the files under [`examples/`](../examples).

### `quick-networks` — KVM networks

Creates one or more libvirt networks (NAT or bridge). Usually run once per environment, before any VMs.

**Source:** `modules/quick-networks`

**Inputs**

| Name | Type | Required | Description |
|------|------|:---:|-------------|
| `networks` | `map(object)` | yes | Map of network profiles. Key = local name. See object fields below. |

Network object fields: `mode` (`"nat"` or `"bridge"`), `domain`, `kvm_network_name`, `mask`, `gateway4`, `nameservers`, `dhcp_mode` (`"static"` or `"dhcp"`), `bridge` (bridge mode only), `autostart`.

**Example**

```hcl
module "kvm_networks" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-networks?ref=main"

  networks = {
    loc1 = {
      kvm_network_name = "qvexample-neta-loc-1"
      mode             = "nat"
      domain           = "la1.local"
      mask             = "24"
      gateway4         = "192.168.200.1"
      nameservers      = ["192.168.200.1"]
      dhcp_mode        = "static"
      autostart        = true
    }
    br0 = {
      kvm_network_name = "qvexample-net-bridge"
      mode             = "bridge"
      bridge           = "br0"
      mask             = "12"
      gateway4         = "172.16.0.1"
      nameservers      = ["172.16.0.1"]
      dhcp_mode        = "static"
      autostart        = true
    }
  }
}
```

See [`examples/example1-network`](../examples/example1-network).

---

### `quick-os-volume` — shared base OS image

Downloads (or references) an OS cloud image once and exposes it as a libvirt volume that several `quick-vm` / `quick-vms` instances can share via `backing_store` (thin provisioning).

**Source:** `modules/quick-os-volume`

**Inputs**

| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `volume_name` | `string` | yes | — | Name of the volume in the libvirt pool |
| `os_name` | `string` | no* | `null` | Built-in profile: `ubuntu_22`, `ubuntu_24`, `rocky_9`, `debian_12` |
| `os_profile` | `object` | no* | `null` | Custom profile (takes priority over `os_name`) |
| `os_image_mode` | `string` | no | `"local"` | `"local"` or `"url"` |
| `storage_pool` | `string` | no | `"default"` | Libvirt storage pool |

\* Provide either `os_name` or `os_profile`.

**Outputs**

- `volume` — object you pass straight to `quick-vm`'s `os_volume` input (contains path, name, pool, and the resolved profile).

**Example**

```hcl
module "base_ubuntu_22" {
  source      = "git::https://github.com/mironx/quick-virt.git//modules/quick-os-volume?ref=main"
  volume_name = "my-ubuntu-22"
  os_name     = "ubuntu_22"
}

module "vm1" {
  source    = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name      = "demo-1"
  os_volume = module.base_ubuntu_22.volume
  # ...
}
```

---

### `quick-vm` — single VM

Provisions one KVM domain with cloud-init, dynamic networks, shared folders, and optional shared base volume.

**Source:** `modules/quick-vm`

> ⚠️ **Prerequisite — libvirt networks must already exist.**
> Every `profile_name` in `networks = [...]` refers to a libvirt network by name. Create them **first** with [`quick-networks`](#quick-networks--kvm-networks) (or the ready-made [`examples/example1-network`](../examples/example1-network)) — otherwise `terraform apply` fails with *"network not found"*.

**Inputs (most common)**

| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `name` | `string` | yes | — | VM name |
| `vm_profile` | `object({ vcpu, memory, cpu, io, network, enable_config })` | yes | — | Compute profile + optional CPU/I/O/network throttling via XML inject (Path A — see [Resource limits](#resource-limits--cpu-io--network-throttling)) |
| `user_data` | `string` | yes | — | Rendered cloud-init `#cloud-config` |
| `networks` | `list(object)` | no | `[]` | Attached networks (order = interface order) |
| `kvm-networks` | `map(object)` | no | `{}` | Global enable/disable + optional manual profile override |
| `os_name` | `string` | no | — | Built-in OS profile name |
| `os_profile` | `object` | no | — | Custom OS profile (wins over `os_name`) |
| `os_volume` | `object` | no | `null` | Output of `quick-os-volume` (wins over both `os_name` and `os_profile`) |
| `os_image_mode` | `string` | no | `"local"` | `"local"` or `"url"` |
| `os_disk_mode` | `string` | no | `"backing_store"` | `"backing_store"` or `"clone"` |
| `fs_type` | `string` | no | `"virtiofs"` | Shared-folder driver: `"virtiofs"` or `"9p"` |
| `shared_folders` | `list(object)` | no | `[]` | Host dirs to mount: `{ source, target, read_only }` |
| `nfs_mounts` | `list(object)` | no | `[]` | NFS shares to mount: `{ host, source, target, options }` — see [NFS mounts](#nfs-mounts-nfs_mounts) |
| `run_before` | `list(string)` | no | `[]` | Commands run very early (after hostname) |
| `run_after` | `list(string)` | no | `[]` | Commands run after shared folders mount |
| `user_data_after` | `string` | no | `null` | Extra `#cloud-config` appended after shared folders |
| `main_storage` | `object({ size })` | no | `null` | Main disk size in GiB |
| `memory_backing` | `object` | no | `{}` | See [Memory backing](#memory-backing) |
| `running` / `autostart` | `bool` | no | `true` / `false` | Power state & host-boot autostart |

**Outputs**

- `vm_name`, `vm_id`, `vm_ips`
- `vm_networks` — resolved interfaces (name + IP)
- `vm_os_profile`, `vm_profile`, `vm_shared_folders`

**Example**

```hcl
module "vm1" {
  source    = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name      = "demo-ubuntu22"
  os_name   = "ubuntu_22"
  user_data = local.user_data
  vm_profile = {
    vcpu   = 2
    memory = 2048
  }
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.50" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.50" },
  ]
}
```

---

### `quick-vms` — multiple VMs (sets)

Provisions **sets of VMs** (e.g. `masters`, `workers`) sharing OS image, profile, and cloud-init. Internally instantiates `quick-vm` per node.

**Source:** `modules/quick-vms`

> ⚠️ **Prerequisite — libvirt networks must already exist.**
> Every key in `kvm-networks = {...}` and every `profile_name` inside a node's `networks` must match a libvirt network name. Create them **first** with [`quick-networks`](#quick-networks--kvm-networks) (or apply [`examples/example1-network`](../examples/example1-network)).

**Inputs**

| Name | Type | Required | Description |
|------|------|:---:|-------------|
| `kvm-networks` | `map(object)` | yes | Same shape as in `quick-vm`. |
| `machines` | `map(object)` | yes | Map of **sets**. Each set has its own OS, profile, cloud-init, and `nodes = [{name, networks}, ...]`. |

A machine set supports every `quick-vm` knob (OS/image/disk modes, `shared_folders`, `run_before`/`run_after`, `memory_backing`, etc.) plus:

- `set_name` — VM name prefix (`${set_name}-${node.name}`)
- `user_data` — **pre-rendered** cloud-init `#cloud-config` (string, required). Render with `templatefile()` in your root module — `quick-vms` no longer renders templates itself.
- `user_data_after` — optional pre-rendered "after" cloud-config fragment

**Outputs**

- `vms_info` — map of every VM with name/id/ips/networks/profiles/shared-folders.
- `kvm-network-profiles` — resolved network profiles (useful for ssh/hosts modules).

**Example**

```hcl
locals {
  ssh = {
    user          = "ubuntu"
    identity_file = "~/.ssh/id_rsa"
    public_key    = file("~/.ssh/id_rsa.pub")
  }

  user_data_master = templatefile("./templates/master-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = "ubuntu123"
    ssh_pub_key   = local.ssh.public_key
  })

  user_data_worker = templatefile("./templates/worker-user-data.tmpl", {
    user_name     = local.ssh.user
    user_password = "ubuntu123"
    ssh_pub_key   = local.ssh.public_key
  })
}

module "vms" {
  source       = "git::https://github.com/mironx/quick-virt.git//modules/quick-vms?ref=main"
  kvm-networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = true }
  }

  machines = {
    masters = {
      set_name   = "demo-master"
      os_name    = "ubuntu_22"
      vm_profile = { vcpu = 1, memory = 2048 }
      user_data  = local.user_data_master
      nodes = [
        { name = "v1", networks = [{ profile_name = "qvexample-neta-loc-2", ip = "192.168.201.3" }] },
        { name = "v2", networks = [{ profile_name = "qvexample-neta-loc-2", ip = "192.168.201.4" }] },
      ]
    }
    workers = {
      set_name   = "demo-worker"
      os_name    = "ubuntu_22"
      vm_profile = { vcpu = 3, memory = 4096 }
      user_data  = local.user_data_worker
      nodes = [
        { name = "v1", networks = [{ profile_name = "qvexample-neta-loc-2", ip = "192.168.201.33" }] },
      ]
    }
  }
}
```

See [`examples/example4-vms`](../examples/example4-vms) and [`examples/example5-vms`](../examples/example5-vms).

---

### `quick-kvm-network-reader` — read existing network

Reads a libvirt network's live settings (CIDR, DHCP, gateway) and exposes them as a Terraform map. Useful when a network was created outside Terraform.

**Source:** `modules/quick-kvm-network-reader`

```hcl
module "net_info" {
  source           = "git::https://github.com/mironx/quick-virt.git//modules/quick-kvm-network-reader?ref=main"
  kvm_network_name = "qvexample-neta-loc-1"
}
```

### Access helpers (`.qv-access/`)

Three sibling modules that **consume the VM info exposed by `quick-vm` / `quick-vms`** and render one file each into `path.root/.qv-access/` — SSH client config, `/etc/hosts`-style aliases, and an Ansible inventory. Each module is independently usable; mix and match as needed.

| Module | Output file | What it generates |
|--------|-------------|-------------------|
| [`quick-access-ssh`](#quick-access-ssh) | `.qv-access/ssh-config` | One `Host` block per VM (primary + suffixed aliases for secondary nets) |
| [`quick-access-hosts`](#quick-access-hosts) | `.qv-access/hosts` | One line per VM in `/etc/hosts` format |
| [`quick-access-ansible`](#quick-access-ansible) | `.qv-access/inventory.ini` | Ansible inventory with groups + `[all:vars]` SSH settings |

> **Migration from old `.qv-ssh/` per-VM helpers:** earlier versions emitted `qv-ssh.config.<vm>.conf` from inside `quick-vm`/`quick-vms` via an `ssh = {...}` block. Both that block and the per-VM emission are **removed**. Render the access files explicitly with the modules below, fed from `module.vms.vms_info_by_set` (or `module.vm.vm_info` for a single VM). End-to-end migration is shown in [`examples/example7-vms`](../examples/example7-vms).

#### Shared input shape — `groups`

All three modules take a `groups = map(list(vm_info))` input — the keys are group/set names, the values are lists of VM-info objects emitted by `quick-vm.vm_info` or `quick-vms.vms_info_by_set`.

- `quick-access-ssh` and `quick-access-hosts` **ignore the group structure** (they dedupe by VM name and render one flat file). Group keys are kept for API parity.
- `quick-access-ansible` **honours the groups** as Ansible inventory groups; a VM can appear in multiple groups.

Building a `groups` map:

```hcl
# from a single quick-vms instance:
groups = module.vms.vms_info_by_set

# adding a standalone quick-vm to a group:
groups = merge(
  module.vms.vms_info_by_set,
  { extra = [module.vm_extra.vm_info] },
)

# merging two quick-vms instances with overlapping keys (use the helper —
# Terraform's built-in merge() would replace one list with the other):
module "merge" {
  source     = "git::https://github.com/mironx/quick-virt.git//modules/quick-access-ansible/helpers/merge_groups?ref=main"
  group_maps = [module.vms1.vms_info_by_set, module.vms2.vms_info_by_set]
}
# module.merge.groups → { masters = [a, b, e, f], workers = [c, d, g, h] }
```

---

#### `quick-access-ssh`

Renders a single `ssh-config` file with one `Host` block per VM (primary network → bare name) and, by default, one extra `Host <vm>.<suffix>` per non-primary interface.

**Source:** `modules/quick-access-ssh`

**Inputs**

| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `groups` | `map(list(vm_info))` | no | `{}` | Group → VM-list map; dedup by VM name on render |
| `ssh` | `object({ user, identity_file })` | yes | — | Emitted in every `Host` block. `identity_file` defaults to `~/.ssh/id_rsa` |
| `primary_network` | `string` | yes | — | Profile name whose IP becomes the bare `Host <vm>` HostName. Falls back to `networks[0].ip` for VMs that don't have it attached |
| `emit_secondary_networks` | `bool` | no | `true` | When `true`, each non-primary network adds `Host <vm>.<suffix>` |
| `network_aliases` | `map(string)` | no | `{}` | Map of `profile_name => suffix`. Missing profiles use the full profile name |
| `relaxed_host_keys` | `bool` | no | `true` | Adds `StrictHostKeyChecking no` + `UserKnownHostsFile /dev/null` per Host (convenient for dev VMs that get recreated) |
| `ssh_config_filename` | `string` | no | `"ssh-config"` | Filename under `.qv-access/` |

**Outputs**

- `ssh_config_path` — absolute path to the generated file
- `vms` — per-VM resolved entries (debug)

**Example**

```hcl
module "ssh" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-access-ssh?ref=main"
  groups = merge(
    module.vms.vms_info_by_set,
    { extra = [module.vm_extra.vm_info] },
  )
  ssh = {
    user          = "ubuntu"
    identity_file = "~/.ssh/id_rsa"
  }
  primary_network = "qvexample-neta-loc-2"
  network_aliases = {
    "qvexample-net-bridge" = "br"
  }
}
```

```bash
# Usage:
ssh -F .qv-access/ssh-config <vm-name>        # primary network
ssh -F .qv-access/ssh-config <vm-name>.br     # bridge alias
```

---

#### `quick-access-hosts`

Same input contract as `quick-access-ssh`, renders a `/etc/hosts`-style file. Suffixes work the same way.

**Source:** `modules/quick-access-hosts`

**Inputs**

| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `groups` | `map(list(vm_info))` | no | `{}` | Group → VM-list map; dedup by VM name on render |
| `primary_network` | `string` | yes | — | Profile name whose IP becomes the bare `<vm>` hosts line |
| `emit_secondary_networks` | `bool` | no | `true` | When `true`, each non-primary network adds `<vm>.<suffix>` |
| `network_aliases` | `map(string)` | no | `{}` | Map of `profile_name => suffix` |
| `hosts_filename` | `string` | no | `"hosts"` | Filename under `.qv-access/` |

**Outputs**

- `hosts_path` — absolute path to the generated file
- `vms` — per-VM resolved entries

**Example output (`.qv-access/hosts`):**

```
# demo-master-v1
192.168.201.3    demo-master-v1
172.20.0.17      demo-master-v1.br
```

Append it to `/etc/hosts` (or symlink) when you want bare names usable outside SSH.

---

#### `quick-access-ansible`

Renders an Ansible `inventory.ini` with groups preserved (unlike `ssh`/`hosts` which dedupe to a flat file). `ansible_host` is the VM's IP on `primary_network` (falls back to `networks[0].ip` if missing).

**Source:** `modules/quick-access-ansible`

**Inputs**

| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `groups` | `map(list(vm_info))` | no | `{}` | Group → VM-list. **Preserved** as Ansible groups; multi-group membership allowed |
| `ssh` | `object({ user, identity_file, password?, become_password? })` | yes | — | Emitted under `[all:vars]` (`ansible_user`, `ansible_ssh_private_key_file`, optional `ansible_password` / `ansible_become_password`) |
| `primary_network` | `string` | yes | — | Profile name used for `ansible_host` |
| `inventory_filename` | `string` | no | `"inventory.ini"` | Filename under `.qv-access/` |

**Outputs**

- `inventory_path` — absolute path
- `vms` — deduped VM list with resolved `primary_ip` (debug)
- `groups` — group → VM-name list (debug)

**Example**

```hcl
module "ansible" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-access-ansible?ref=main"
  groups = module.vms.vms_info_by_set
  ssh = {
    user          = "ubuntu"
    identity_file = "~/.ssh/id_rsa"
    password      = "demo123"        # optional — for `ansible_password`
  }
  primary_network = "qvexample-neta-loc-2"
}
```

```bash
# Usage:
ansible -i .qv-access/inventory.ini all -m ping
ansible-playbook -i .qv-access/inventory.ini site.yml
```

---

#### Group helpers (`quick-access-ansible/helpers/`)

Two tiny pure-Terraform helpers for assembling the `groups` map without resorting to inline `merge()` / `concat()` gymnastics.

##### `merge_groups`

Merges N `groups` maps; on overlapping keys, lists are **concatenated** (not replaced like Terraform's built-in `merge()`).

```hcl
module "merge" {
  source     = "git::https://github.com/mironx/quick-virt.git//modules/quick-access-ansible/helpers/merge_groups?ref=main"
  group_maps = [
    module.vms1.vms_info_by_set,    # { masters = [a, b], workers = [c, d] }
    module.vms2.vms_info_by_set,    # { masters = [e, f], cache    = [g, h] }
  ]
}
# module.merge.groups → { masters = [a, b, e, f], workers = [c, d], cache = [g, h] }
```

##### `add_vms_to_group`

Appends a list of VMs to a named group (created if missing). Existing members preserved.

```hcl
module "add_extra_to_masters" {
  source     = "git::https://github.com/mironx/quick-virt.git//modules/quick-access-ansible/helpers/add_vms_to_group?ref=main"
  groups     = module.merge.groups
  group_name = "masters"
  vms        = [module.vm_extra.vm_info]
}
# module.add_extra_to_masters.groups feeds the next helper / quick-access-* module
```

Chain these in sequence to build complex inventories (custom groups, supersets, all-nodes). End-to-end pattern in [`examples/example7-vms`](../examples/example7-vms).

---

## Feature deep dives

### OS profiles (built-in vs custom)

You get three mutually-exclusive ways to tell a VM which OS to run. **Priority** (highest wins): `os_volume` → `os_profile` → `os_name`.

#### A) `os_name` — built-in profile

The simplest path. The module already knows the image path, network template, and interface naming.

| `os_name` | Local image | Network template | Interface |
|-----------|-------------|------------------|-----------|
| `ubuntu_22` | `ubuntu-2204.qcow2.base` | netplan | `enp0s*` |
| `ubuntu_24` | `ubuntu-2404.qcow2.base` | netplan | `enp0s*` |
| `rocky_9` | `rocky-9.qcow2.base` | networkmanager | `eth*` |
| `debian_12` | `debian-12.qcow2.base` | netplan | `enp0s*` |

```hcl
module "vm" {
  source  = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name    = "demo"
  os_name = "ubuntu_24"
  # ...
}
```

#### B) `os_profile` — custom profile

Override the defaults (e.g. different image path, different interface naming).

```hcl
module "vm" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name   = "demo"
  os_profile = {
    image            = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
    network_template = "netplan"
    interface_naming = "enp0s"
    fs_type          = "virtiofs"
  }
  # ...
}
```

#### C) `os_volume` — shared base (recommended for many VMs)

See next section.

---

### Shared base volume (`os_volume`)

When you need N identical VMs, download the image **once**, then point every VM at the same base volume with `os_disk_mode = "backing_store"`. Each VM gets its own thin delta disk.

```hcl
module "base_ubuntu_22" {
  source      = "git::https://github.com/mironx/quick-virt.git//modules/quick-os-volume?ref=main"
  volume_name = "demo-ubuntu-22"
  os_name     = "ubuntu_22"
}

module "vm_a" {
  source       = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name         = "demo-A"
  os_volume    = module.base_ubuntu_22.volume  # <— thin delta on top of the base
  os_disk_mode = "backing_store"
  # ...
}

module "vm_b" {
  source       = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name         = "demo-B"
  os_volume    = module.base_ubuntu_22.volume
  os_disk_mode = "backing_store"
  # ...
}
```

**Why it matters:** a fresh Ubuntu image is ~600 MB. Ten VMs with `backing_store` take ~600 MB + 10 × delta. Ten VMs with `clone` take ~10 × 600 MB.

See [`examples/example3c-vm`](../examples/example3c-vm) (VMs A/B/C) and [`examples/example5-vms`](../examples/example5-vms).

---

### Disk modes (`backing_store` vs `clone`)

| Mode | Disk layout | Pros | Cons |
|------|-------------|------|------|
| `backing_store` (default) | Thin delta on top of a shared base volume | Fast, cheap | Base must stay alive; does **not** work with `os_volume` if the base file isn't readable by the VM user — the module guards this for you |
| `clone` | Full copy per VM | Independent from the base | Slow, lots of disk |

**Guardrails:**

- `os_volume + os_disk_mode = "clone"` is **blocked by validation** (libvirt 0.9.x file-permission limitation on root:root 600 files in the default pool).
- Use `clone` with `os_name` or `os_profile` instead (see `examples/example5-vms` → `vms_C` / `vms_D`).

---

### Image modes (`local` vs `url`)

`os_image_mode` controls where the image comes from when using `os_name`:

- `"local"` (default) — expects the image to already exist under `/var/lib/libvirt/images/<name>.qcow2.base`. Use `task images:download:ubuntu22` (etc.) to fetch.
- `"url"` — the module downloads from the upstream cloud-image URL on first `apply`.

```hcl
module "base_ubuntu_22" {
  source        = "git::https://github.com/mironx/quick-virt.git//modules/quick-os-volume?ref=main"
  volume_name   = "demo-ubuntu-22"
  os_name       = "ubuntu_22"
  os_image_mode = "url"   # no manual download needed
}
```

---

### Networks (static, DHCP, profile_name)

`networks` is a **list** — its **order decides interface order** (`networks[0]` → first NIC, `networks[1]` → second NIC).

#### Static IP, resolved from profile_name

```hcl
networks = [
  { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.50" },
  { profile_name = "qvexample-net-bridge", ip = "172.16.0.50" },
]
```

The profile (CIDR, gateway, nameservers) is loaded automatically from the libvirt network.

#### DHCP

```hcl
networks = [
  {
    profile_name = "qvexample-neta-loc-1",
    profile = {
      kvm_network_name = "qvexample-neta-loc-1"
      dhcp_mode        = "dhcp"
      gateway4         = ""
      mask             = ""
      nameservers      = []
    }
  }
]
```

#### Manual profile (override)

Pass a full `profile` object inline to skip the automatic lookup — handy when the network was created outside Terraform.

---

### Global network on/off (`kvm-networks`)

Turn entire networks on/off across **all** VMs without editing the per-VM `networks` list. Set once at the top level, pass it to every `quick-vm` / `quick-vms`:

```hcl
locals {
  kvm_networks = {
    "qvexample-neta-loc-2" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }  # <— disables bridge everywhere
  }
}
```

A VM whose `networks` list references `qvexample-net-bridge` will silently skip that NIC. This is the easiest way to prepare a laptop-friendly offline variant of a lab.

---

### Shared folders (virtiofs vs 9p)

Mount a host directory inside the VM as `/mnt/<target>`. The module wires up the libvirt filesystem device, the cloud-init `fstab` entry, and the `mount` command for you.

```hcl
module "vm_with_share" {
  source    = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name      = "demo-share"
  os_name   = "ubuntu_22"
  fs_type   = "virtiofs"          # or "9p"
  shared_folders = [
    { source = "${abspath(path.module)}/vmdata", target = "vmdata" }
  ]
  run_after = [
    "mountpoint -q /mnt/vmdata && echo ready > /mnt/vmdata/hello.txt",
  ]
  # ...
}
```

| Driver | Speed | File ownership in VM | Caveats |
|--------|-------|----------------------|---------|
| `virtiofs` (default) | Fast | Writes land as `root:root`, readable | Needs `virtiofsd` on the host (`task setup:install-virtiofsd`) |
| `9p` | Slower | `libvirt-qemu:kvm 600` via `access_mode=mapped` | **Not supported on Rocky Linux 9** — the kernel ships without the 9p module. The module blocks this combo with a clear error. |

**Pre-flight checklist:**

1. `task setup:enable-shared-folders` — grants `libvirt-qemu` access to your files.
2. `task setup:check-shared-folders-drivers` — confirms drivers are available.
3. The `source` directory must exist and contain a `.gitkeep` (validation checks this — the error tells you the exact command to run).

See [`examples/example3c-vm`](../examples/example3c-vm) (VMs F1/F2) and [`examples/example5-vms`](../examples/example5-vms).

---

### NFS mounts (`nfs_mounts`)

When `virtiofs` / `9p` don't fit — e.g. you need the same share **across many hosts**, Rocky Linux 9 (no 9p kernel module), or you want a less capricious driver — use `nfs_mounts`. The module generates a cloud-init fragment that installs the NFS client, declares the mount in `/etc/fstab`, and mounts it on first boot. **Nothing about NFS leaks into your `user_data` template.**

**Input shape**

```hcl
nfs_mounts = [
  {
    host    = "172.16.0.1"              # NFS server IP or hostname
    source  = "/home/devx/vm-shares"    # path exported by the NFS server
    target  = "vm-shares"               # → mounted at /mnt/vm-shares in the VM
    options = "defaults"                # optional (default: "defaults")
  }
]
```

| Field | Required | Default | Notes |
|-------|:---:|---------|-------|
| `host` | ✓ | — | NFS server IP/hostname reachable from the VM |
| `source` | ✓ | — | Absolute path exported by the server (must match `/etc/exports`) |
| `target` | ✓ | — | Mount-point name — always lands at `/mnt/<target>` in the VM |
| `options` | — | `defaults` | Any `mount -t nfs` options (e.g. `"ro,soft,timeo=30"`) |

**Pre-flight (one-time on the host)**

1. Install the NFS server:
   ```bash
   task setup:install-nfs-server
   ```
2. Configure the export (creates the directory, sets ownership, updates `/etc/exports`, runs `exportfs -ra`):
   ```bash
   task setup:configure-nfs-export DIR=/home/$USER/vm-shares CIDR=192.168.100.0/24
   ```
   Parameters: `DIR` (abs path, required) · `CIDR` (network allowed to mount, required) · `OPTIONS` (NFS export options, default `rw,sync,no_subtree_check,no_root_squash`) · `OWNER` (`user:group`, default = caller). The task is idempotent — re-running it replaces the existing entry for `DIR`.
3. Verify from another machine:
   ```bash
   showmount -e <host-ip>
   ```

**Single-VM example**

```hcl
module "vm_nfs" {
  source     = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  name       = "demo-nfs"
  os_name    = "ubuntu_22"
  user_data  = local.user_data
  vm_profile = { vcpu = 1, memory = 2048 }

  nfs_mounts = [
    { host = "172.16.0.1", source = "/home/devx/vm-shares", target = "vm-shares" }
  ]
  run_after = [
    "mountpoint -q /mnt/vm-shares && echo ready > /mnt/vm-shares/${var.name}.ok",
  ]

  networks = [
    { profile_name = "neta-loc-1", ip = "192.168.100.70" }
  ]
}
```

After `terraform apply` and first boot, inside the VM:

```bash
$ mountpoint /mnt/vm-shares
/mnt/vm-shares is a mountpoint
$ ls /mnt/vm-shares
demo-nfs.ok
```

**Multi-VM example (`quick-vms`)**

`nfs_mounts` is available at the **set** level — every node in the set gets the same mount:

```hcl
module "cluster" {
  source       = "git::https://github.com/mironx/quick-virt.git//modules/quick-vms?ref=main"
  kvm-networks = { "neta-loc-2" = { enabled = true } }

  machines = {
    workers = {
      set_name   = "demo-worker"
      os_name    = "ubuntu_22"
      vm_profile = { vcpu = 2, memory = 4096 }
      user_data  = local.user_data_worker   # rendered with templatefile() in your locals
      ssh        = local.ssh

      nfs_mounts = [
        { host = "172.16.0.1", source = "/home/devx/vm-shares", target = "vm-shares" }
      ]

      nodes = [
        { name = "v1", networks = [{ profile_name = "neta-loc-2", ip = "192.168.201.70" }] },
        { name = "v2", networks = [{ profile_name = "neta-loc-2", ip = "192.168.201.71" }] },
      ]
    }
  }
}
```

**What the module does under the hood**

A `nfs-mounts.cfg` MIME fragment is injected into cloud-init (between `shared-folders.cfg` and `run-after.cfg`):

```yaml
#cloud-config
merge_how: [{ name: list, settings: [append] }, { name: dict, settings: [no_replace, recurse_list] }]
packages:
  - nfs-common        # or nfs-utils on Rocky 9 — picked automatically from os_name
mounts:
  - [ "172.16.0.1:/home/devx/vm-shares", "/mnt/vm-shares", "nfs", "defaults", "0", "0" ]
runcmd:
  - mkdir -p /mnt/vm-shares
  - mount -a
```

You never see it — keep your `user_data.tmpl` focused on app-level concerns.

**When to pick NFS over virtiofs/9p**

| Need | Pick |
|------|------|
| Fastest read/write, laptop/dev box | `virtiofs` |
| Works on Ubuntu/Debian, no host daemon install | `9p` |
| Works on **Rocky Linux 9** | `virtiofs` or `nfs_mounts` (not `9p`) |
| Shared between **multiple hosts** (not just this KVM host) | `nfs_mounts` |
| User wants "just mount it, I don't care about micro-optimisations" | `nfs_mounts` |

---

### Cloud-init hooks (`run_before`, `run_after`, `user_data_after`)

The module builds a **multipart MIME cloud-init** so you can inject commands without rewriting your `user_data` template. Order of execution:

```
hostname → run_before → user_data → shared-folders mount → nfs-mounts → run_after → user_data_after
```

#### `run_before` / `run_after` — quick command lists

```hcl
module "vm" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  # ...
  run_before = [
    "echo 'starting bootstrap' >> /var/log/boot.log",
  ]
  run_after = [
    "mountpoint -q /mnt/vmdata && echo ready > /mnt/vmdata/${var.prefix}-F1.txt",
    "systemctl enable my-service",
  ]
}
```

Both are `list(string)` — each element becomes its own `runcmd` entry. They use cloud-init's `merge_how: [append]`, so adding them never clobbers your main `user_data`.

#### `user_data_after` — full cloud-config fragment

When a few lines aren't enough, pass a complete `#cloud-config` document that runs **after** the shared folders are mounted:

```hcl
user_data_after = templatefile("${path.module}/templates/post-mount.tmpl", {
  app_version = "1.2.3"
})
```

---

### Memory backing

Required for `virtiofs` and `9p` shared folders (they need `memory_access.mode = "shared"`). Defaults are sensible — you rarely need to touch this.

```hcl
module "vm" {
  source = "git::https://github.com/mironx/quick-virt.git//modules/quick-vm?ref=main"
  # ...
  memory_backing = {
    shared       = true    # default
    source       = null    # or "memfd" / "file"
    locked       = false
    discard      = false
    nosharepages = false
  }
}
```

Turn `shared = false` only when you're sure you don't use shared folders **and** need the extra hardening.

---

### Resource limits — CPU, I/O & network throttling

Cap how much CPU time, disk I/O and network bandwidth a VM can consume — independent from the `vcpu`/`memory` allocation. Useful for reproducing cloud-like resource contention on a dev box, stress-testing apps under slow I/O, or chaos engineering.

Quick-virt provides **two paths** for throttling, with different trade-offs:

| Path | Mechanism | When to use |
|---|---|---|
| **A — `enable_config` XML inject** | Values live in `vm_profile.{cpu,io,network}` and are baked into the libvirt domain XML at `terraform apply`. | Persistent baseline throttle known at terraform-time. Lightweight: no extra modules. |
| **B — `quick-throttle*` triplet** | Three standalone modules emit `.qv-limits/*.ini` definitions + apply/clear scripts that drive `virsh` for live changes. | Chaos sessions, hot tweak without re-running `terraform apply`, IO/network burst, multi-scenario mappings. |

Both paths use the same underlying libvirt mechanisms (cgroups via `cputune` / `iotune`, traffic shaping via `<bandwidth>`). They can coexist on the same set of VMs — Path A handles VMs that should always run with a fixed throttle, Path B handles ad-hoc experimentation on top.

See [`examples/example6-vms`](../examples/example6-vms) for a working side-by-side example (baseline VM + Path A throttled VM + Path B 3-node worker set).

#### Path A — `enable_config` XML inject (lightweight, terraform-driven)

```hcl
vm_profile = {
  vcpu   = 4
  memory = 4096

  cpu = {
    limit = {
      percent = 25        # 25 % of total allocated CPU (~ 1 core of 4)
    }
  }

  io = {
    vda = {
      bytes_unit      = "MB"
      read_bytes_sec  = 10
      write_bytes_sec = 5
      read_iops_sec   = 1000
      write_iops_sec  = 500
    }
  }

  network = {
    "0" = {
      rate_unit = "MB"
      inbound  = { average = 10, peak = 50, burst = 1 }
      outbound = { average = 5,  peak = 20, burst = 1 }
    }
  }

  enable_config = true    # default — bake limits into libvirt domain XML
}
```

After `terraform apply`, limits are visible immediately in the domain XML and at the runtime cgroup level:

```bash
virsh dumpxml <vm> | grep -E "cputune|iotune|<bandwidth"
virsh schedinfo <vm>
virsh blkdeviotune <vm> vda
virsh domiftune <vm> <vnet-name>
```

**Limitations of Path A:**
- I/O burst attributes (`*_max`, `*_max_length`) may be rejected by the dmacvicar provider's iotune schema — for burst, use Path B.
- Value changes require `terraform apply`. No hot tweak via `.ini` editing.
- Network bandwidth IS supported on `vm_profile.network.<idx>` and goes into the interface's `<bandwidth>` element.

#### Path B — `quick-throttle*` triplet (sidecar live-apply workflow)

Three composable modules:

| Module | Produces |
|---|---|
| [`quick-throttle`](../modules/quick-throttle/) | `.qv-limits/<prefix>-{cpu,disk,network}-<name>.ini` — named throttle profiles per axis |
| [`quick-throttle-apply`](../modules/quick-throttle-apply/) | `.qv-limits/<prefix>-throttle.ini` — VM ↔ profile mapping, all-null bootstrap with an auto-discovery comment header |
| [`quick-throttle-runner`](../modules/quick-throttle-runner/) | `.qv-limits/qv-throttle.{apply,clear}.sh` — generic consumer scripts that take a mapping file as argument |

```hcl
module "throttle" {
  source     = "git@github.com:mironx/quick-virt.git//modules/quick-throttle?ref=vX.Y.Z"
  output_dir = path.root
  prefix     = "lab"

  cpu_configs = {
    cap25 = { limit = { percent = 25 } }
  }
  disk_configs = {
    slow = {
      vda = {
        bytes_unit      = "MB"
        read_bytes_sec  = 10
        write_bytes_sec = 5
        # burst — Path B can apply these via virsh
        write_bytes_sec_max        = 20
        write_bytes_sec_max_length = 5
      }
    }
  }
  network_configs = {
    bandit = { "0" = { rate_unit = "MB", inbound = { average = 10 }, outbound = { average = 5 } } }
  }
}

module "throttle_apply" {
  source             = "git@github.com:mironx/quick-virt.git//modules/quick-throttle-apply?ref=vX.Y.Z"
  output_dir         = path.root
  prefix             = "lab"
  vms                = [module.vm1.vm_info, module.vm2.vm_info]
  available_profiles = module.throttle.available_files   # populates header comment
}

module "throttle_runner" {
  source     = "git@github.com:mironx/quick-virt.git//modules/quick-throttle-runner?ref=vX.Y.Z"
  output_dir = path.root
}
```

After `terraform apply`:

```bash
# Generated artefacts in .qv-limits/
ls .qv-limits/
# → lab-cpu-cap25.ini    lab-disk-slow.ini    lab-network-bandit.ini
#   lab-throttle.ini     qv-throttle.apply.sh    qv-throttle.clear.sh

# Edit the mapping file — assign profile filenames to specific VMs
$EDITOR .qv-limits/lab-throttle.ini
# Change `cpu_profile = null` to `cpu_profile = lab-cpu-cap25.ini`, etc.

# Apply via virsh — runtime effect immediate (cpu/disk also --config; network is --live only)
bash .qv-limits/qv-throttle.apply.sh .qv-limits/lab-throttle.ini

# Iterate: edit profile values or mapping, re-run apply.sh — no terraform apply needed
$EDITOR .qv-limits/lab-cpu-cap25.ini
bash .qv-limits/qv-throttle.apply.sh .qv-limits/lab-throttle.ini

# Clear all throttles for VMs listed in the mapping
bash .qv-limits/qv-throttle.clear.sh .qv-limits/lab-throttle.ini
```

**Multi-scenario isolation** — instantiate multiple `quick-throttle` / `quick-throttle-apply` triplets with different `prefix` values. Each gets its own family of files in `.qv-limits/`; one shared `qv-throttle.apply.sh` (from `quick-throttle-runner`) consumes any mapping file by filename.

**Format version** — the mapping file carries `format_version` in its `[meta]` section; `apply.sh` validates and aborts on mismatch (defensive guard when bumping module versions).

#### CPU limit (`cpu.limit`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `percent` | number | — | **HARD cap.** Percentage of total allocated CPU. `percent = 100` ≈ full allocation, no throttle. |
| `period_us` | number | `100000` | **HARD cap.** CFS period in microseconds (kernel scheduler window). |
| `quota_us` | number | computed from `percent` | **HARD cap.** CFS quota in microseconds. If set, overrides `percent`. |
| `shares` | number | libvirt default (1024) | **SOFT priority** — relative weight under CPU contention. **NOT a hard cap.** |

> ⚠ **`shares` is NOT a CPU limit.** It only affects scheduling priority when multiple VMs compete for the same physical CPUs — VMs with higher `shares` get scheduled more often, but a VM with `shares = 100` on an otherwise-idle host can still consume 100% CPU. For a real cap use `percent` or `period_us`+`quota_us`. Libvirt range: 2-262144, default 1024.

Formula: `quota_us = vcpu × period_us × percent / 100`.
Example: `vcpu=4, percent=25, period_us=100000` → `quota_us=100000` (= 1 core-equivalent).

**Mode resolution (used by Path B's `qv-throttle.apply.sh` when consuming a `cpu-<name>.ini` profile):**

| In the profile `.ini` | Mode | Effective values |
|---|:---:|---|
| `percent` set, raw fields commented | **PERCENT** | `quota_us = vcpu × period_us × percent / 100` (vcpu queried via `virsh dominfo`, period defaults to `100000`) |
| both `period_us` AND `quota_us` set | **RAW** | values used verbatim, `percent` ignored |
| neither set | **SKIP** | CPU section is a no-op |

For Path A, only `percent` or explicit `period_us` + `quota_us` are baked into the XML at terraform-time (vcpu is known statically from `vm_profile.vcpu`).

**Verify after apply:**
```bash
virsh schedinfo <vm-name>            # shows vcpu_period, vcpu_quota, cpu_shares
```

#### I/O throttle naming convention (`io.<dev>`)

Every parameter decomposes from a predictable pattern:

```
<direction>_<metric>_sec[_max[_length]][_unit]
    │            │       │     │         │
    │            │       │     │         └─ bytes-only: enum B/KB/MB/GB
    │            │       │     └─── burst duration, always SECONDS
    │            │       └──────── burst peak (may exceed baseline)
    │            └──────────────── "bytes" (bandwidth) or "iops" (op count)
    └───────────────────────────── "read" or "write"
```

**All fields (each optional):**

| Field | Unit | Role |
|-------|------|------|
| `read_bytes_sec` | bytes/s (or `_unit`) | Baseline read bandwidth |
| `write_bytes_sec` | bytes/s (or `_unit`) | Baseline write bandwidth |
| `read_iops_sec` | ops/s | Baseline read op rate |
| `write_iops_sec` | ops/s | Baseline write op rate |
| `read_bytes_sec_max` | bytes/s (or `_unit`) | Burst peak read bandwidth |
| `read_bytes_sec_max_length` | **seconds** | How long the read-bytes burst may sustain |
| `write_bytes_sec_max` | bytes/s (or `_unit`) | Burst peak write bandwidth |
| `write_bytes_sec_max_length` | **seconds** | Write-bytes burst duration |
| `read_iops_sec_max` | ops/s | Burst peak read IOPS |
| `read_iops_sec_max_length` | **seconds** | Read-IOPS burst duration |
| `write_iops_sec_max` | ops/s | Burst peak write IOPS |
| `write_iops_sec_max_length` | **seconds** | Write-IOPS burst duration |

**Conventions:**

1. **`_sec` means "per second"** — it is a rate, not a cumulative count. `read_bytes_sec = 10485760` is "10 MB **per second**", not "10 MB total".
2. **`bytes` vs `iops`** — `bytes` caps **how much data**, `iops` caps **how many operations**. One IO op may transfer 4 KB or 1 MB, so they are independent levers.
3. **`_unit` applies only to `bytes` fields** — IOPS are dimensionless counts, no multiplier.
4. **`_max_length` is always seconds** — no `_length_unit` suffix; libvirt only supports seconds.
5. **Only burst has `_length`** — baseline is "forever at this rate", no duration.

#### Unit multipliers

Byte fields support a unit enum so you can write human-friendly values. Precedence (highest wins):

1. Per-field: `<field>_unit` (e.g. `write_bytes_sec_unit = "KB"`)
2. Disk-level: `bytes_unit`
3. Default: `"B"` (raw bytes)

| Unit | Multiplier (binary) |
|------|--------------------:|
| `"B"` | 1 |
| `"KB"` | 1 024 |
| `"MB"` | 1 048 576 |
| `"GB"` | 1 073 741 824 |

```hcl
io = {
  vda = {
    bytes_unit      = "MB"
    read_bytes_sec  = 10               # 10 MB/s
    write_bytes_sec = 5                #  5 MB/s

    # per-field override — this one stays in KB:
    write_bytes_sec_max        = 512   # 512 KB/s peak
    write_bytes_sec_max_unit   = "KB"
    write_bytes_sec_max_length = 3
  }
}
```

#### Worked example — baseline + burst

```hcl
io = {
  vda = {
    bytes_unit = "MB"

    # Baseline — the sustained rate the VM always gets
    write_bytes_sec = 5       # 5 MB/s continuous

    # Burst — if idle, VM can spike to 20 MB/s for up to 5 seconds
    write_bytes_sec_max        = 20
    write_bytes_sec_max_length = 5
  }
}
```

Translation: *"VM writes up to 20 MB/s for 5 seconds after an idle period, then falls back to 5 MB/s sustained."*

Token-bucket model: tokens accumulate at the baseline rate while idle; a burst spends them faster; once drained the throttle clamps back to baseline until tokens refill.

#### Network bandwidth (`vm_profile.network`)

Per-interface inbound/outbound rate caps via libvirt's native `<bandwidth>` element. Keyed by interface index (matches order of `networks = [...]`).

```hcl
vm_profile = {
  # ... cpu, io, enable_* ...

  network = {
    "0" = {                      # first interface
      rate_unit = "MB"           # interpret numeric rates as MiB/s (burst as MiB)
      inbound = {
        average = 10             # 10 MiB/s sustained download
        peak    = 50             # 50 MiB/s burst peak
        burst   = 1              #  1 MiB burst bucket
      }
      outbound = {
        average = 5              # 5 MiB/s sustained upload
        peak    = 20
        burst   = 1
        floor   = 1              # min 1 MiB/s guaranteed (NAT/QoS networks only)
      }
    }
  }
}
```

**Direction:** `inbound` = traffic into the VM (download), `outbound` = traffic out (upload).

**Fields (each optional):**

| Field | Unit | Role |
|-------|------|------|
| `average` | KiB/s (or `_unit`) | Baseline — sustained rate |
| `peak` | KiB/s (or `_unit`) | Burst peak — chwilowy szczyt |
| `burst` | KiB (or `_unit`) | Burst bucket size — how much data at peak in one shot |
| `floor` | KiB/s (or `_unit`) | Minimum guaranteed rate (outbound only, NAT/QoS networks) |

**Rate units (`rate_unit` and per-field `*_unit`):** `"KB"` (1 KiB), `"MB"` (1024 KiB), `"GB"` (1048576 KiB). Default: `"KB"` — raw libvirt units.

> **Libvirt's base unit is KiB/s** for rates and **KiB** for burst (binary kilobytes). The module converts from user-friendly `rate_unit` to KiB before passing to libvirt.

**Live apply (Path B)** uses `virsh domiftune` (per-interface, by target dev name which the runner script resolves from `virsh domiflist`):

```bash
virsh domiftune <vm> vnet0 \
  --inbound  "10240,51200,1024,0" \    # avg,peak,burst,floor
  --outbound "5120,20480,1024" \
  --live
```

> Network throttle is **live-only** in Path B — `--config` is omitted because the inactive XML (which `--config` writes to) doesn't contain the `<target dev='vnetN'/>` runtime alias. Result: network throttle does not survive VM reboot. CPU and disk axes ARE persisted via `--config`.

Clear mode zeroes every attached NIC (no-op on NICs that were never throttled).

#### Apply flag — `enable_config`

| Flag | Default | Effect |
|------|---------|--------|
| `enable_config` | `true` | Inject `vm_profile.{cpu,io,network}` values into the libvirt domain XML via native `cpu_tune`, `disks[*].io_tune`, and per-interface `<bandwidth>`. Persistent — survives VM restart. |

For the live-apply path (sidecar `.ini` + `qv-throttle.{apply,clear}.sh`), see the [`quick-throttle*` triplet](#path-b--quick-throttle-triplet-sidecar-live-apply-workflow) above.

#### Edge cases / silent failures

Things that **don't error** at `terraform apply` or `apply.sh` but quietly produce no effect — easy to miss when debugging "why isn't my limit working":

| Field / scenario | Symptom | Reason |
|---|---|---|
| `vm_profile.io.vdb` (or any non-vda) with `enable_config = true` | Throttle silently ignored | Path A only wires `disks[0]` (vda) into `<iotune>`. Multi-disk support is Path B territory (`disk_configs[name] = map(dev → throttle)`). Tracked: [`to-improve-limits.md` #5](./to-improve-limits.md). |
| `network.<idx>.outbound.floor` on a bridge / non-QoS network | No error, no effect | `<bandwidth><outbound floor>` is only honored on NAT networks with QoS enabled. Bridge mode bypasses libvirt's QoS layer. Use `inbound`+`outbound` `average`/`peak`/`burst` instead. |
| IO `*_max` (burst) attrs with `enable_config = true` | May be rejected by provider | dmacvicar/libvirt 0.9.x iotune schema may not accept all burst attributes. If you need burst, use Path B (`quick-throttle` profile + `qv-throttle.apply.sh`) where they're applied via `virsh blkdeviotune`. |
| Network throttle (Path B) survives VM reboot | No — only `--live` is applied | `apply.sh` omits `--config` for `domiftune` because the inactive XML lacks `<target dev='vnetN'/>` (runtime alias). CPU and disk axes DO persist via `--config`. |
| Editing `<prefix>-throttle.ini` while `vms` set changes | Edits lost in changed sections | quick-throttle-apply regenerates the mapping when `vms` membership / disks / networks change. Manual assignments in unchanged sections survive; changed sections reset to `null`. |
| `cpu.limit.shares` "doesn't cap my CPU" | Working as designed | `shares` is **soft priority** under contention, not a hard cap (see warning above). For a real CPU cap use `percent` or `period_us`+`quota_us`. |
| `cpu.limit.percent = 200` accepted historically | Now rejected | Added validation (Terraform `validation` block) — `percent` must be in `[1, 100]`. Similar checks: `period_us > 0`, `bytes_unit ∈ {B,KB,MB,GB}`, `rate_unit ∈ {KB,MB,GB}`, `outbound.floor <= outbound.average`. |