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

## Bootstrap-only semantics — what to expect

After `terraform apply`:
- File is created if missing, with all-null values
- File is **regenerated** if the set of VMs (or their disks/networks) changed
  → your manual edits in changed sections are lost
- File is **untouched** if VM set is unchanged (deterministic sort by VM name
  ensures stable content)

For chaos sessions: avoid running `terraform apply` mid-session. Make your
edits, run downstream apply.sh, observe, iterate, then revert via apply.sh
clear (when implemented).

## Outputs

| Output | Type | Description |
|---|---|---|
| `mapping_file` | `string` | path to throttle.ini |
| `vm_names` | `list(string)` | sorted VM names in the mapping |

## Related modules

- [quick-throttle](../quick-throttle/) — generates the per-axis profile `.ini`
  files (`cpu-*.ini`, `disk-*.ini`, `network-*.ini`) that this mapping
  references.
- *Future:* `quick-throttle-runner` (TBD) — reads throttle.ini, locates
  referenced profiles, invokes `virsh` per VM/axis.
