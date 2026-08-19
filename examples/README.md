# Quick-Virt Examples

Runnable Terraform root modules demonstrating the quick-virt modules — from a single VM to multi-set clusters with resource limits and generated access files.

All examples use the `qvexample-` name prefix so their resources are easy to spot (and clean up) next to your own. Passwords in the examples (`ubuntu123`, `demo123`) are demo-only console fallbacks — never reuse them outside local KVM dev. Examples that inject an SSH key expect `~/.ssh/id_rsa.pub` to exist.

Run pattern: `terraform init && terraform apply` in the chosen directory. Some directories ship `tf-plan.sh` / `tf-apply.sh` / `tf-destroy.sh` wrappers that pass the right `-var-file` for you.

## Contents

| Directory                                                                      | Modules exercised                          | One-liner                                                                  |
|--------------------------------------------------------------------------------|--------------------------------------------|----------------------------------------------------------------------------|
| [`prerequisites/01-networks-nat-bridge`](#prerequisites01-networks-nat-bridge) | `quick-networks`                           | Create the NAT + bridge networks every other example needs                 |
| [`01-network-reader-info`](#01-network-reader-info)                            | `quick-kvm-network-reader`                 | Introspect existing libvirt networks — no VMs created                      |
| [`02a-vm-network-variants`](#02a-vm-network-variants)                          | `quick-vm`                                 | 7 VMs covering the network-config matrix (static / DHCP / reader)          |
| [`02b-vm-custom-storage`](#02b-vm-custom-storage)                              | `quick-vm`                                 | Same matrix, plus a custom-sized main disk                                 |
| [`02c-vm-os-image-modes`](#02c-vm-os-image-modes)                              | `quick-vm`, `quick-os-volume`              | OS image modes (`os_volume` / `os_name` / `os_profile`) across 4 distros   |
| [`02d-vm-nfs-mounts`](#02d-vm-nfs-mounts)                                      | `quick-vm`                                 | One VM per OS, all mounting the same host NFS share                        |
| [`03-vms-masters-workers`](#03-vms-masters-workers)                            | `quick-vms`                                | Declarative masters + workers cluster from one `machines` map              |
| [`04-vms-shared-os-volume`](#04-vms-shared-os-volume)                          | `quick-vms`, `quick-os-volume`             | One base image, many thin VMs; `clone` vs `backing_store`                  |
| [`05-vms-throttle-limits`](#05-vms-throttle-limits)                            | `quick-vm`, `quick-vms`, `quick-throttle*` | CPU / I/O / network limits — both delivery paths side by side              |
| [`06-vms-access-helpers`](#06-vms-access-helpers)                              | `quick-vms`, `quick-access-*`              | Generated ssh-config, hosts file, and Ansible inventory with custom groups |
| [`07-vm-guest-agent`](#07-vm-guest-agent)                                      | `quick-vm`                                 | qemu-guest-agent channel auto-attach + memory lock / swap-off plumbing     |

---

## prerequisites/01-networks-nat-bridge

Creates the libvirt networks used by all VM examples — **run this first**.

- Feeds a plain map from `networks.tfvars` into `quick-networks`:
  - two NAT networks (`qvexample-neta-loc-1/2`) with their own domains, gateways, and static-DHCP mode,
  - one bridge network (`qvexample-net-bridge`) attached to a Linux bridge `br0`.
- The bridge entry only works if `br0` exists on the host — create it with `quick-virt bridge:create PHYS_IF=<nic> BRIDGE_NAME=br0` (or comment the entry out).
- Ships `tf-apply.sh` / `tf-plan.sh` / `tf-destroy.sh` that pass `-var-file=networks.tfvars`.

The whole root is three lines of wiring; the interesting part is the data shape — NAT vs bridge is just one field:

```hcl
qvexample-neta-loc-1 = {
  kvm_network_name = "qvexample-neta-loc-1"
  mode             = "nat"
  domain           = "la1.local"
  mask             = "24"
  gateway4         = "192.168.200.1"
  nameservers      = ["192.168.200.1"]
  dhcp_mode        = "static"
  autostart        = true
}

qvexample-net-bridge = {
  kvm_network_name = "qvexample-net-bridge"
  mode             = "bridge"          # ← the only structural difference
  bridge           = "br0"             # must exist on the host
  mask             = "12"
  gateway4         = "172.16.0.1"
  # ...
}
```

## 01-network-reader-info

Read-only introspection of existing libvirt networks — **creates no VMs and no networks**.

- Fans out `quick-kvm-network-reader` over a list of network names with `for_each`.
- Exposes two views per network:
  - `profile` — the normalized shape (`kvm_network_name`, `mask`, `gateway4`, `mode`, `error`, …) that `quick-vm` consumes,
  - `all_for_debug` — the raw parsed data, handy when a network misbehaves.
- Under the hood the reader shells out to `virsh net-dumpxml` via an `external` data source, so it needs `virsh`, `jq`, `xmllint`, and `ipcalc` on the host.

```hcl
module "net_info" {
  for_each         = toset(["qvexample-net-bridge", "qvexample-neta-loc-1", "qvexample-neta-loc-2"])
  source           = "../../modules/quick-kvm-network-reader"
  kvm_network_name = each.value
}

output "kvm_networks_profile" {
  value = { for net, mod in module.net_info : net => { profile = mod.profile } }
}
```

Run `terraform apply` and read the outputs — this is the fastest way to see what a "network profile" actually contains before wiring it into VMs.

## 02a-vm-network-variants

Seven single VMs (`quick-vm`), each demonstrating one cell of the network-configuration matrix:

- **vm1 / vm7** — static IP on both networks; the module resolves everything else from `profile_name` (the internal reader auto-detects gateway, mask, DNS).
- **vm2** — DHCP on both networks, with the profile passed **inline** instead of via the reader.
- **vm3–vm6** — DHCP on a single network only (local-only and bridge-only variants).
- One shared cloud-init template (`templates/user-data.tmpl`) parameterized with user/password from `terraform.tfvars`; `tf-*.sh` wrappers included.

The key contrast — reader-resolved static vs hand-rolled inline DHCP profile:

```hcl
# Static IP: give the module just a name + address, the reader fills in the rest
networks = [
  { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.16" },
  { profile_name = "qvexample-net-bridge", ip = "172.16.0.16" }
]

# Inline DHCP: skip the reader entirely by supplying the profile object yourself
networks = [
  { profile_name = "qvexample-neta-loc-1",
    profile = { dhcp_mode = "dhcp", gateway4 = "", mask = "", nameservers = [],
                kvm_network_name = "qvexample-neta-loc-1" } }
]
```

## 02b-vm-custom-storage

The same seven-VM network matrix as `02a`, with storage added to the picture:

- **vm1** overrides the default main disk with `main_storage = { size = 40 }` (GiB) — the rest keep the module default (20 GiB).
- Comes with `variables.tf`, `outputs.tf`, `terraform.tfvars`, and `tf-*.sh` wrappers — the most "complete root module" layout among the single-VM examples.

```hcl
module "vm1" {
  source     = "../../modules/quick-vm"
  name       = "${local.prefix}-vt1_static_both"
  os_name    = "ubuntu_22"
  vm_profile = local.vm_profile

  main_storage = {
    size = 40          # GiB — override the 20 GiB default
  }

  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.16" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.16" }
  ]
}
```

## 02c-vm-os-image-modes

How a VM gets its OS disk — the three image modes, exercised for **four distros** (Ubuntu 22/24, Rocky 9, Debian 12) via per-OS submodules under `./modules/`:

- **shared `os_volume`** — one base volume, VMs attach via backing store,
- **standalone `os_name`** — built-in profile shorthand, image resolved per VM,
- **custom `os_profile`** — bring-your-own image path + network template.
- Also demonstrates the **global network toggle**: `kvm_networks` lets you disable a network for every VM in one place instead of editing each `networks` list.

```hcl
locals {
  kvm_networks = {
    "qvexample-neta-loc-1" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }   # flip to true once br0 exists
  }
}

module "ubuntu_22_test" {
  source       = "./modules/vm-ubuntu-22-test"
  prefix       = "${local.prefix}-u22"
  kvm_networks = local.kvm_networks       # one switch propagates to every VM inside
  vm_profile   = { vcpu = 1, memory = 2048 }
  user_data    = local.user_data
  vmdata_path  = "${abspath(path.module)}/vmdata"
}
```

## 02d-vm-nfs-mounts

One VM per OS (4 distros), all mounting the **same NFS share exported by the host** — a cross-distro test of `nfs_mounts` and `run_after`.

- Pre-flight on the host:
  - `quick-virt setup:install-nfs-server`
  - `quick-virt setup:configure-nfs-export DIR=/home/$USER/vm-shares CIDR=192.168.200.0/24`
- Each VM mounts the share at `/mnt/vm-shares` and — via `run_after` — drops a marker file you can watch appear on the host, proving mount + boot ordering worked end to end.
- The NFS server address is simply the NAT gateway of `qvexample-neta-loc-1` (that IP **is** the host on that network).

```hcl
module "vm_ubuntu_22" {
  source     = "../../modules/quick-vm"
  name       = "${local.prefix}-ubuntu22"
  os_name    = "ubuntu_22"

  nfs_mounts = [
    { host = "192.168.200.1", source = "/home/devx/vm-shares", target = "vm-shares" }
  ]

  # Runs in the guest after boot — the file shows up on the HOST in the export dir
  run_after = [
    "mountpoint -q /mnt/vm-shares && echo ready > /mnt/vm-shares/02d-vm-nfs-mounts/${local.prefix}-ubuntu22.txt",
  ]
  # ...
}
```

## 03-vms-masters-workers

A whole cluster from **one declarative map** — the canonical `quick-vms` example.

- Two sets in a single `machines` map:
  - `masters` — 3 nodes, 1 vCPU / 2 GiB / 30 GiB each,
  - `workers` — 4 nodes, 3 vCPU / 4 GiB / 40 GiB each.
- Per-set cloud-init templates (`master-user-data.tmpl` / `worker-user-data.tmpl`) with the SSH public key injected from `~/.ssh/id_rsa.pub`.
- Every node lists its own static IPs on both networks; `vms_info` output aggregates the result for downstream tooling.

```hcl
module "vms" {
  source       = "../../modules/quick-vms"
  kvm-networks = local.kvm_networks

  machines = {
    masters = {
      set_name     = "${local.prefix}-master"
      os_name      = "ubuntu_22"
      vm_profile   = { vcpu = 1, memory = 2048 }
      main_storage = { size = 30 }
      user_data    = local.user_data_master
      nodes = [
        { name = "v1", description = "master 1/3",
          networks = [{ profile_name = "qvexample-neta-loc-2", ip = "192.168.201.3" }] },
        # ... v2, v3
      ]
    }
    workers = {}   # same shape, different sizing and template
  }
}
```

## 04-vms-shared-os-volume

Disk-provisioning strategies for VM sets — **download the image once, decide how VMs consume it**:

- `base_os` (`quick-os-volume`) materializes one Ubuntu 22 base volume.
- **`vms_A` + `vms_B`** — two independent `quick-vms` instances share that volume via `os_volume` (thin backing store: fast create, small disks).
- **`vms_C`** — `os_disk_mode = "clone"` with `os_name`: each VM gets its own **full copy** (no shared backing file).
- **`vms_D`** — `clone` with a custom `os_profile` (your own image path + netplan template) — the bring-your-own-image variant.
- Bonus: `shared_folders` (virtiofs) mounts a host directory into the A/B sets.

```hcl
module "base_os" {
  source      = "../../modules/quick-os-volume"
  volume_name = "${local.prefix}-os-volume"
  os_name     = "ubuntu_22"
}

machines = {
  servers = {
    os_volume = module.base_os.volume     # thin: shared backing store
    # ...
  }
}

machines = {
  cloned = {
    os_name      = "ubuntu_22"
    os_disk_mode = "clone"                # full copy per VM — survives base changes
    # ...
  }
}
```

## 05-vms-throttle-limits

CPU / disk-I/O / network limits, showing **both delivery paths side by side** so you can compare behavior on one host:

- **Path A — XML inject** (`enable_config = true`): limits declared inside `vm_profile` are baked into the libvirt domain XML at create time.
  - `vm_loose` — no limits, the baseline for comparison,
  - `vm_throttled` — 25% CPU cap, MB-denominated disk I/O caps, inbound/outbound network shaping.
  - Verify right after apply: `virsh dumpxml qvms-ex6-throttled | grep -E "cputune|iotune|bandwidth"`.
- **Path B — live apply** (`quick-throttle` / `-apply` / `-runner` triplet): a 3-worker set with **no** limits in HCL; profiles land as `.qv-limits/ex6-*.ini` files and you drive `virsh` with generated scripts:
  1. `ls .qv-limits/` — see the generated profiles + mapping,
  2. edit `.qv-limits/ex6-throttle.ini` — assign profiles to specific workers,
  3. `bash .qv-limits/qv-throttle.apply.sh .qv-limits/ex6-throttle.ini` (and `…clear.sh` to undo).
- Burst attributes (`*_max`, `*_max_length`) are a Path-B-only feature — the provider's iotune schema rejects them in Path A.

```hcl
# Path A: limits live inside vm_profile and persist in the domain XML
vm_profile = merge(local.base_profile, {
  cpu     = { limit = { percent = 25 } }
  io      = { vda = { bytes_unit = "MB", read_bytes_sec = 10, write_bytes_sec = 5 } }
  network = { "0" = { rate_unit = "MB",
                      inbound  = { average = 10, peak = 50, burst = 1 },
                      outbound = { average = 5,  peak = 20, burst = 1 } } }
  enable_config = true          # ← the switch that turns profile into XML
})

# Path B: HCL only *generates* profiles; assignment happens post-apply in the .ini
module "throttle" {
  source      = "../../modules/quick-throttle"
  prefix      = "ex6"
  cpu_configs = { cap25 = { limit = { percent = 25 } }, cap50 = { limit = { percent = 50 } } }
  # ...
}
```

## 06-vms-access-helpers

Everything after `apply`: turning VM info into **files you actually use** — ssh-config, an `/etc/hosts` block, and an Ansible inventory (all rendered into `.qv-access/`).

- Two `quick-vms` instances (`vms1`, `vms2`) plus one standalone `quick-vm` (`vm_extra`) — deliberately overlapping group names to exercise merging.
- **`merge_groups` helper**: concatenates lists on overlapping keys (built-in `merge()` would silently *replace* one list with the other — this is the pitfall the example demonstrates).
- **`add_vms_to_group` chain**: builds custom groups on top of the base ones — `vm_extra` joins `masters` *and* `workers`, a hand-picked `super` group, and a `nodes` group spanning every cluster VM.
- Renderers: `quick-access-ansible` (inventory with groups + `[all:vars]` SSH config), `quick-access-hosts`, `quick-access-ssh` — with `network_aliases` so the bridge IP of `vm-x` is reachable as `vm-x.br`.

```hcl
# Concatenate groups from two quick-vms instances (merge() would clobber them)
module "merge_groups" {
  source     = "../../modules/quick-access-ansible/helpers/merge_groups"
  group_maps = [module.vms1.vms_info_by_set, module.vms2.vms_info_by_set]
}

# Chain group builders, then render the inventory
module "ansible_add_super" {
  source     = "../../modules/quick-access-ansible/helpers/add_vms_to_group"
  groups     = module.ansible_add_extra_to_workers.groups
  group_name = "super"
  vms        = concat(local.picked_workers, [module.vm_extra.vm_info])   # hand-picked workers + the standalone VM
}

module "ansible" {
  source          = "../../modules/quick-access-ansible"
  groups          = module.ansible_add_nodes.groups
  ssh             = { user = "ubuntu", identity_file = "~/.ssh/id_rsa", password = "ubuntu123" }
  primary_network = "qvexample-neta-loc-2"
}
```

## 07-vm-guest-agent

A focused single-VM test of the **qemu-guest-agent channel** — and of the memory-lock / swap-off plumbing.

- `quick-vm` auto-attaches the agent virtio channel when `user_data` contains the string `qemu-guest-agent` (the template installs the package, which trips the detection).
- The channel must be `type='unix'` (host socket) — `type='pty'` looks similar but breaks `virsh --mode agent`.
- Doubles as a smoke test for `memory_backing = { locked = true }` + `swap_level = "disabled"`.
- The output hands you the verification command; a ping back means the whole chain (channel → agent in guest → socket on host) works.
- Heads-up: this example uses its own network name (`neta-loc-3`, `192.168.102.0/24`) rather than the `qvexample-*` set — adjust to a network that exists on your host before applying.

```hcl
module "vm" {
  source     = "../../modules/quick-vm"
  name       = "qv-agent-test"
  os_name    = "ubuntu_22"
  user_data  = local.user_data          # contains "qemu-guest-agent" → channel auto-attached
  vm_profile = { vcpu = 2, memory = 2048 }

  memory_backing = { locked = true }    # mlock guest RAM on the host
  swap_level     = "disabled"           # swap off inside the guest
  # ...
}

output "agent_test" {
  value = "virsh qemu-agent-command qv-agent-test '{\"execute\":\"guest-ping\"}'"
}
```
