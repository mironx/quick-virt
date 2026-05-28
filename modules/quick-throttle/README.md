# quick-throttle

Standalone module that generates libvirt VM throttle definitions as `.ini`
files. Configuration is **split per axis** (CPU / Disk / Network) — each
collection produces its own family of `.ini` files. The module is a pure
factory: it does not know about specific VMs and does not apply anything.

## Output layout

```
.qv-limits/
├── .gitignore
├── cpu-<name>.ini       (one per entry in var.cpu_configs)
├── disk-<name>.ini      (one per entry in var.disk_configs)
└── network-<name>.ini   (one per entry in var.network_configs)
```

Each file is self-contained. Downstream tooling (manual apply.sh, future
composer module, external scripts) maps VMs to these definitions and runs
`virsh schedinfo` / `virsh blkdeviotune` / `virsh domiftune` accordingly.

## Usage

```hcl
module "throttle" {
  source = "git@github.com:mironx/quick-virt.git//modules/quick-throttle?ref=v0.3.0"

  output_dir = path.root

  cpu_configs = {
    cap25 = { limit = { percent = 25 } }
    cap75 = { limit = { percent = 75 } }
  }

  disk_configs = {
    slow1 = {
      vda = {
        bytes_unit     = "MB"
        read_bytes_sec = 10
        write_bytes_sec = 5
        read_iops_sec  = 200
        write_iops_sec = 100
      }
    }
    cassandra_load = {
      vda = { bytes_unit = "MB", read_iops_sec = 80, write_iops_sec = 40 }
      vdb = { bytes_unit = "MB", read_iops_sec = 50 }
    }
  }

  network_configs = {
    bandit = {
      "0" = {
        rate_unit = "MB"
        inbound  = { average = 10 }
        outbound = { average = 5 }
      }
    }
  }
}
```

## Axes are fully independent

You can populate any subset of `cpu_configs` / `disk_configs` /
`network_configs`. Empty collections produce no files. There is no concept
of a "bundled preset" here — composition (matching VM-X to `cpu-cap25` +
`disk-slow1`) is the consumer's responsibility.

## Disk and network configs support multi-target

`disk_configs[<name>]` is `map(target_dev → throttle)` — one disk config
can constrain multiple disks (vda + vdb). Each populates an `[io.<dev>]`
section in the same file.

`network_configs[<name>]` is `map(interface_index → bandwidth)` — same
pattern. Index is a string ("0", "1", ...) matching the order of
`networks` in the consuming VM.

## Unit normalization

The module pre-normalises values to libvirt's native units before writing:

| Field | Input unit | Output (in .ini) |
|---|---|---|
| `disk.*_bytes_sec[_max]` | `bytes_unit` = B/KB/MB/GB | raw bytes |
| `network.*.{average,peak,burst,floor}` | `rate_unit` = KB/MB/GB | KiB/s (libvirt's native) |
| `cpu.limit.percent` | — | passed through |
| `cpu.limit.{period,quota}_us` | — | passed through (microseconds) |

CPU `quota_us` from `percent` is NOT pre-computed (needs `vcpu` of target
VM, which this module doesn't know). Downstream `apply.sh` resolves it at
apply time via `virsh dominfo`.

## Outputs

| Output | Type | Description |
|---|---|---|
| `cpu_files` | `map(string)` | name → file path |
| `disk_files` | `map(string)` | name → file path |
| `network_files` | `map(string)` | name → file path |
| `cpu_names` | `list(string)` | sorted names |
| `disk_names` | `list(string)` | sorted names |
| `network_names` | `list(string)` | sorted names |
