# Limits roadmap

Aktualny plan działania dla rozszerzania API limitów (post-refaktoring
`quick-throttle*` triplet). Derived z analizy
[`to-improve-limits.md`](./to-improve-limits.md) — ten plik to konkretne
fazy do robienia, tamten to pełna baza historyczna + nieuporządkowane
pomysły.

## Status po refaktoringu

**Zamknięte przez sam refaktoring (no action needed):**

| # | Item | Jak rozwiązane |
|---|---|---|
| 7 | `limits_output_dir` parametryzacja | quick-throttle*/output_dir jako mandatory var |
| 9 | Profile presets | quick-throttle ma named `{cpu,disk,network}_configs` jako pierwsza-class API |
| 15 | `enable_config` vs `enable_live` conflict | Path A i B fizycznie rozdzielone na różne moduły |
| 16 | Orphan files po destroy | terraform `local_file` handles cleanup automatycznie |
| 18 | Multi-consumer race | `prefix` (mandatory) isolation w quick-throttle |

**Częściowo zaadresowane (drobne doc'i zostały):**

| # | Item | Co zostało |
|---|---|---|
| 2 | `shares` ≠ hard cap | Explicit warning w USAGE.md (2-3 linie) |
| 3 | Silent-fail mapa | Rozszerzyć "Limitations" subsekcję (outbound.floor on bridge, io.vdb on enable_config) |
| 19 | cgroup v1/v2 paths | N/A dopóki używamy tylko `virsh` (abstracted); relevant z #4 / #6 |

---

## Faza A — Clean & Document (~1.5h)

Najszybsza wartość, zero ryzyka. **Zacznij tutaj.**

| Lp. | # | Item | Effort | Lokalizacja |
|---|---|---|---|---|
| 1 | #1 | Validation blocks | ~1h | `quick-vm/variables.tf` + `quick-throttle/variables.tf` |
| 2 | #2 | Doc: `shares` warning | ~10 min | `doc/USAGE.md` — CPU limit table |
| 3 | #3 | Silent-fail mapa | ~20 min | `doc/USAGE.md` — nowa subsekcja "Edge cases" |

**Konkretne validations do dodania (#1):**
- `cpu.limit.percent ∈ [1, 100]`
- `cpu.limit.period_us > 0`
- `cpu.limit.shares ∈ [2, 262144]` (cgroup range)
- `io.<dev>.bytes_unit ∈ {B, KB, MB, GB}`
- `network.<idx>.rate_unit ∈ {KB, MB, GB}`
- `network.<idx>.outbound.floor <= average`
- `prefix` w quick-throttle*/quick-throttle-apply — match regex (już jest)

> **Note:** original Faza A plan included **#17 (state drift `lifecycle.ignore_changes`)** as ~30 min item. Investigation showed `local_file.lifecycle.ignore_changes = [content]` does NOT prevent the provider from rewriting the file when state content differs from disk — needs a different pattern (`null_resource` + `local-exec` + conditional `[ -f file ] || write`). Moved to Tier 3 below.

---

## Faza B — Symmetric Path A/B

### ✅ #5 Multi-disk native `enable_config` (DONE)

Dodane:
- `extra_disks = [{ target_dev, size_gb, pool? }]` var w `quick-vm/variables.tf` + 3 validations (regex /^vd[b-z]$/, unique, size>0)
- `libvirt_volume.extra_disk` (for_each) — thin qcow2 volumes
- Refaktor `local.native_io_tune_vda` (single) → `local.native_io_tunes` (map per dev) z `coalesce(...,0)` fix dla sparse io
- `libvirt_domain.devices.disks` używa `concat([vda], [for d in extra_disks], [cdrom])` z dynamicznym io_tune lookup per device
- `vm_info.disks` output: `concat(["vda"], [for d in extra_disks : d.target_dev])` — quick-throttle-apply widzi wszystkie writable disks
- Bug fix w `validation.tf:136-139` — `try(t.X, 0) >= 0` zwracało `null >= 0` error dla sparse io; fixed via `coalesce(try(t.X, 0), 0)`

End-to-end test (`example8-multidisk-test`): 3 dyski (vda + vdb + vdc), każdy z osobnym `<iotune>` w XML, sparse configs działają (vdb/vdc tylko `read_iops_sec` bez bytes — wcześniej silent fail, teraz native).

### ⏸ #14 I/O priority `blkio.weight` (DEFERRED — wymaga więcej pracy)

**Powód deferral:**
- `virsh blkdeviotune` (używane przez quick-throttle-runner) **NIE ma** flagi `--weight`. Per-device weight wymaga `virsh blkiotune <vm> --device-weights "/path/to/disk1,500,/path/to/disk2,300"`.
- Wymaga device PATH (nie target_dev) → apply.sh musi query `virsh domblklist` żeby zmapować vdb → `/var/lib/libvirt/images/<vm>-vdb.qcow2`.
- Path A (XML inject): nieznane czy dmacvicar/libvirt provider 0.9.x wystawia `<blkiotune>` element libvirt domain (do research).
- Per-VM weight (single `--weight`) prostsze ale mniej expressywne.

**Przeniesione do Tier 3 / future:** Implementacja gdy realny use case ("nasza Cassandra dostaje za mało IO pod contention od background worker"). Wcześniej research dmacvicar provider schema.

**Faza B summary:** **1 z 2 items DONE** (#5 multi-disk + bonus bug fix w validation.tf). #14 świadomie odłożone.

---

## Faza B.5 — State drift preservation (#17, ~2-3h)

Moved from Faza A after empirical investigation showed naive `lifecycle.ignore_changes` doesn't work for `local_file`. Real implementation needs:

```hcl
resource "null_resource" "bootstrap_mapping" {
  count = var.preserve_edits ? 1 : 0

  triggers = {
    vms_set_hash = sha256(jsonencode(local.vm_specs))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      mkdir -p "$(dirname '${local._filename}')"
      cat > '${local._filename}' <<'INI_EOF'
${local._content}
INI_EOF
    EOT
  }
}
```

Tradeoffs:
- terraform destroy doesn't remove file (add `when = destroy` provisioner if needed)
- File content is regenerated when `vms` set changes (`triggers` change → null_resource recreated → provisioner re-runs)
- Between vms-set changes: file is untouched → user edits survive
- Plus an opt-in flag `preserve_edits = optional(bool, false)` in quick-throttle-apply
- `available_profiles` header doesn't auto-refresh until next vms-set change — document trade-off

Worth doing only if you find yourself losing mapping edits to accidental `terraform apply` runs during chaos sessions.

## Faza C — Nowe osie (8-12h, YAGNI gate)

**Robić TYLKO gdy pojawi się konkretny use case.** Każda oś = dużo
dodanej powierzchni API. Worth balancing przeciw "feature creep".

| Lp. | # | Item | Effort | Use case trigger |
|---|---|---|---|---|
| 7 | #4 | Memory limits (`memory_limit`) | ~3h | "Co jeśli leader Cassandry leci OOM po 30s pressure?" |
| 8 | #11 | CPU pinning / cpuset | ~2h | NUMA-aware workload, latency-sensitive isolation |
| 9 | #12 | NUMA topology | ~2h | Stacja 7810 (2× Xeon = 2 NUMA nodes) chcesz testować cross-socket effects |
| 10 | #13 | Hugepages | ~1h | DB/JVM heap performance tuning |

**Każda z osi** wymaga:
- Rozszerzenia `quick-vm/variables.tf` (Path A)
- Rozszerzenia `quick-throttle/variables.tf` (Path B)
- Path B: dorzucenie axis-templates (e.g. `memory.ini.tmpl`, `pinning.ini.tmpl`)
- Path B: extension w `quick-throttle-runner/templates/apply.sh.tmpl` (parser + virsh commands)
- Path B: update format_version coordination
- Doc updates

To nie jest mała robota. Implementuj **per axis na żądanie**, nie wszystko od razu.

---

## Faza D — Chaos UX (selektywnie, gdy potrzeba)

Quality of life dla aktywnych chaos sessions.

| Lp. | # | Item | Effort | Wartość |
|---|---|---|---|---|
| 11 | #10 | `--verify` flag w apply.sh | ~1h | CI/automation friendliness, `set -e` + apply.sh → automatic test |
| 12 | #8 | Ramp / interpolate mode | ~4h (nowy moduł) | Najmocniejsze chaos capability — progressive throttle |
| 13 | #21 | JSON output z apply.sh | ~1h | CI parsing JSON output |
| 14 | #22 | Audit log | ~30 min | Lab provenance (multi-user lap + stacja) |

**Ramp mode szczegół:** propozycja nowego modułu `quick-throttle-ramp`
lub flag w `quick-throttle-runner`:
```bash
bash qv-throttle.ramp.sh <mapping> --field write_bytes_sec --from 100 --to 1 --duration 5m --steps 10
```
Iteruje po krokach, edytuje `.ini`, runuje apply.sh, czeka.

---

## Pomijam (świadomie)

| # | Item | Powód |
|---|---|---|
| #6 | PID limits | Niche, 5-linijkowa implementacja gdy będzie potrzebna |
| #19 | cgroup v1/v2 detection | N/A dopóki tylko `virsh`; reactive — dorobić gdy memory/PID limits dodawane (#4, #6) |
| #20 | Cross-distro test matrix | Important ale 3h pracy + CI setup. Lower priority dopóki nie ma realnych distro regressji. |
| #23 | libvirt 1.x migration | Future-tracking — śledzić provider milestones, action gdy 1.x RC. |

Plus z "Out of scope" w to-improve-limits.md: GPU/vGPU, ballooning auto-tune,
distributed throttle coord, real-time adaptation — wszystko poza scope.

---

## Kolejność rekomendowana

```
Faza A  ──►  Faza B  ──►  [pauza, YAGNI gate]  ──►  Faza C selektywnie  ──►  Faza D
~1.5h        ~4h                                     per axis, ~2-3h each

Faza B.5 (#17 state drift)  ──  opportunistic, ~2-3h, gdy realny ból
```

**Po Fazie A+B** quick-virt limits API jest "complete" dla typowego
chaos-engineering use case w labie. Fazy C+D to **luxury features**
do robienia gdy realny use case przyciśnie.

**Faza B.5 (#17)** — odrębna, dorobić gdy chaos sessions zaczną realnie
kolidować z `terraform apply`. Wymaga zmiany paradygmatu (`null_resource`
+ provisioner zamiast `local_file`).

## Linki

- Pełna analiza items 1-23: [`to-improve-limits.md`](./to-improve-limits.md)
- API spec: [`USAGE.md` → Resource limits](./USAGE.md#resource-limits--cpu-io--network-throttling)
- Architektura: [`STRUCTURE.md`](./STRUCTURE.md)
- Modules: [`MODULES.md`](./MODULES.md), [`quick-throttle*/README.md`](../modules/)
