# quick-throttle-apply

Generates a single mapping file (`.qv-limits/throttle.ini`) that binds VMs
to throttle profiles produced by [quick-throttle](../quick-throttle/).

This module is **bootstrap-only**: the generated file always starts with
`null` for every field. You edit the file manually to assign profiles for
chaos sessions.

## Output format

```ini
[k3s-master-m1]
cpu_profile        = null
disk_profile.vda   = null
network_profile.0  = null

[k3s-master-m2]
cpu_profile        = null
disk_profile.vda   = null
network_profile.0  = null
```

After a chaos session edit:

```ini
[k3s-master-m2]
cpu_profile        = cpu-cap25.ini
disk_profile.vda   = disk-slow1.ini
network_profile.0  = null            ; null = unthrottle this axis
```

### Conventions

- **Value semantics:**
  - `null` → downstream apply.sh resets that axis to defaults (clears the limit)
  - `<filename>.ini` → literal filename in `.qv-limits/` (matches what
    quick-throttle produces: `cpu-<name>.ini`, `disk-<name>.ini`,
    `network-<name>.ini`)
- **Per-target dot-suffix:**
  - `disk_profile.<dev>` — one entry per writable disk (vda, vdb, ...)
  - `network_profile.<idx>` — one entry per interface (0, 1, ...)
- `cpu_profile` has no sub-targets (CPU is whole-VM).

## Usage

```hcl
module "throttle_apply" {
  source = "git@github.com:mironx/quick-virt.git//modules/quick-throttle-apply?ref=v0.3.0"

  output_dir = path.root

  vms = [
    module.master_m1.vm_info,
    module.master_m2.vm_info,
    module.master_m3.vm_info,
    module.agent["a1"].vm_info,
    module.agent["a2"].vm_info,
  ]
}
```

The module reads only three fields from each VM: `name`, `disks`, `networks[*].index`.
Pass `quick-vm.vm_info` directly — extra fields are tolerated and ignored.

## Bootstrap-only semantics — state drift

After `terraform apply`:
- File is created if missing, with all-null values
- File is **regenerated on every apply** — `local_file` overwrites content to match HCL even if you edited the file in between (terraform's `lifecycle.ignore_changes = [content]` does NOT prevent this for `local_file`; the provider rewrites the file when state-content differs from disk)
- Workaround for chaos sessions: avoid running `terraform apply` between editing the mapping and running `qv-throttle.apply.sh`. Once `apply.sh` has fired, throttles are in cgroups + libvirt XML — terraform regenerating the mapping `.ini` doesn't undo them (only future `apply.sh` runs read the regenerated file)

Tracked as a future improvement requiring a `null_resource` + `local-exec` pattern (or similar) — see [`doc/limits-roadmap.md` → Tier 3](../../doc/limits-roadmap.md).

## Outputs

| Output | Type | Description |
|---|---|---|
| `mapping_file` | `string` | Path to throttle.ini |
| `vm_names` | `list(string)` | Sorted VM names in the mapping |

## Related modules

- [quick-throttle](../quick-throttle/) — generates the per-axis profile `.ini`
  files (`cpu-*.ini`, `disk-*.ini`, `network-*.ini`) that this mapping
  references.
- *Future:* `quick-throttle-runner` (TBD) — reads throttle.ini, locates
  referenced profiles, invokes `virsh` per VM/axis.
