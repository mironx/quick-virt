# quick-vm limits API — to-improve

> **Status note (2026):** the live-apply pipeline previously inside
> `quick-vm` / `quick-vms` (sidecar `.qv-limits/qv-limits.{spec,apply,clear}.<vm>.{ini,sh}`
> + set-level `apply-all` / `clear-all` scripts) was **extracted** into a
> separate three-module triplet: `quick-throttle` (per-axis profile factory),
> `quick-throttle-apply` (VM↔profile mapping bootstrap), `quick-throttle-runner`
> (generic apply/clear scripts). See module READMEs and
> [`doc/USAGE.md` → Resource limits](./USAGE.md#resource-limits--cpu-io--network-throttling).
>
> Items below were written against the OLD sidecar pipeline. Many are now
> resolved or moot in the new triplet design — re-read with that lens. Kept
> for historical context + ideas still applicable to the **`enable_config`
> XML inject path** (quick-vm) or transferrable to the triplet.

Notatki do potencjalnej poprawy/rozszerzenia API `vm_profile.{cpu,io,network}`
w module `quick-vm`. Spis z review API z perspektywy konsumenta
(use case: chaos engineering w lab, distributed systems testing).

**Kontekst:** API limitów było **mocną stroną quick-virt**. Po refaktoringu
limit lifecycle jest podzielony — `quick-vm` ma minimal XML-inject (`enable_config`
+ `vm_profile.{cpu,io,network}`), live-apply z hot tweak siedzi w `quick-throttle*`
triplet. Punktem wyjścia poprawek nie jest "to słabe", tylko "skoro API jest
dobre, można je dociągnąć do tego, co już oferuje cloud-providers".

---

## Quick wins (low effort, high value)

### 1. Validation blocks w `variables.tf`

**Problem:** absurd values są akceptowane:
- `percent = 200` — przechodzi przez Terraform validation, dopiero libvirt może odrzucić
- `floor > average` — żaden warning
- `period_us = 0` lub negatywne — cryptic error w XML
- `bytes_unit = "TB"` — sniff fail dopiero przy templatefile

**Fix:** dodać `validation { condition = ... }` blocks pod kluczowymi
polami. Koszt: ~30 linii kodu, zysk: user widzi błąd przy `terraform plan`
zamiast przy `apply` z libvirt cryptic message.

Sugerowane validations:

```hcl
variable "vm_profile" {
  type = object({ ... })

  validation {
    condition = (
      try(var.vm_profile.cpu.limit.percent, null) == null ||
      (var.vm_profile.cpu.limit.percent >= 1 && var.vm_profile.cpu.limit.percent <= 100)
    )
    error_message = "cpu.limit.percent must be in [1, 100]."
  }

  validation {
    condition = alltrue([
      for k, v in coalesce(var.vm_profile.io, {}) :
      try(v.bytes_unit, "B") == null || contains(["B", "KB", "MB", "GB"], v.bytes_unit)
    ])
    error_message = "io.<dev>.bytes_unit must be one of: B, KB, MB, GB."
  }

  validation {
    condition = alltrue([
      for idx, n in coalesce(var.vm_profile.network, {}) :
      try(n.outbound.floor, null) == null ||
      try(n.outbound.average, null) == null ||
      n.outbound.floor <= n.outbound.average
    ])
    error_message = "network.<idx>.outbound.floor must be <= average."
  }
}
```

Dodać też warning że `outbound.floor` działa tylko na NAT z QoS — silent
ignore na bridge jest mylący.

### 2. Doc note: `shares` ≠ hard cap

**Problem:** `cpu.limit.shares` jest exponowane razem z `percent`, `period_us`,
`quota_us` — user assume że pasują do tej samej osi (hard CPU cap). Ale
`shares` to **soft priority pod CPU contention** (relative weight), nie
hard cap.

**Fix:** komentarz inline w schemacie + dedykowana sekcja w USAGE.md:

```hcl
cpu = optional(object({
  limit = optional(object({
    percent   = optional(number)  # HARD cap, % całkowitej alokacji CPU
    period_us = optional(number)  # HARD cap, CFS scheduler window
    quota_us  = optional(number)  # HARD cap, CFS quota per period
    shares    = optional(number)  # SOFT prio (weight under contention),
                                  # default 1024. NOT a hard cap.
  }))
}))
```

### 3. Doc: silent-fail mapa

**Problem:** kilka miejsc gdzie limit jest **cicho ignorowany** na "wrong"
config — user nie wie:
- `outbound.floor` → ignored na bridge/non-QoS
- `enable_config` → no-burst dla CPU (libvirt provider 0.9.x limit)
- `io.vdb` → ignored przy `enable_config` (tylko `vda` w native XML)

**Fix:** sekcja "Silent failures and edge cases" w USAGE.md, tabelka.

---

## Medium effort (worth tackling)

### 4. Memory limits

**Problem:** brakuje całej osi memory throttling. Mamy `vm_profile.memory`
jako allocation, ale nic dla:
- balloon driver (dynamiczny resize bez recreate)
- swap throttle (`memory.swappiness`)
- OOM behavior (`memory.oom_control`)
- memory pressure limits (`memory.high`, `memory.max`)

**Use case:** "Co jeśli leader cluster Cassandry ma 16 GB a follower zostaje
OOM-killed po 30s pressure?" — obecnie nie zrobisz tego deklaratywnie.

**Propozycja:**

```hcl
vm_profile.memory_limit = optional(object({
  swappiness            = optional(number)   # 0-100, default 60
  balloon               = optional(bool)     # enable virtio-balloon
  oom_kill_disable      = optional(bool)     # cgroup memory.oom_control
  soft_limit_mib        = optional(number)   # memory.high (soft pressure)
  hard_limit_mib        = optional(number)   # memory.max (hard cap)
}))
```

Sidecar `apply.sh` ma sekcję `[memory]`, `apply.sh` woła
`virsh setmem`, `virsh memtune`, ew. cgroup write.

### 5. Multi-disk native enable_config

**Problem:** komentarz w `main.tf:548` mówi `_io_vda = try(local.io_limits["vda"], null)`
— hardcoded tylko `vda`. Multi-disk VM z `vdb`/`vdc` w XML nie dostanie native iotune.

`enable_live` to obsługuje (iterating po wszystkich devs), ale dwie ścieżki
kodowe dla tej samej feature = nieoczywiste z perspektywy usera.

**Fix:** `disks[*].io_tune` w libvirt_domain — iterować po wszystkich
kluczach `io_limits`, dopasować do disk by target dev. Wymaga że quick-vm
wie o wszystkich dyskach VM (obecnie tylko main_storage = vda).

Jak zaczniemy supportować multi-disk via `extra_disks = [...]` (kolejny
feature), to multi-dev native throttling będzie naturalną częścią.

### 6. PID/process limits

**Problem:** brak `cgroup pids.max`. Classic chaos test "fork bomb"
nie ma jak symulować deklaratywnie.

**Propozycja:**

```hcl
vm_profile.process_limit = optional(object({
  max_pids = optional(number)
}))
```

Implementacja: `<resource><pids tag/>` w libvirt domain XML (jeśli
provider supportuje) lub sidecar via `cgcreate` / `cgset` na hoście dla
QEMU process scope.

### 7. Brak `enable_live` path overriding

**Problem:** sidecar files lądują w `path.root/.qv-limits/`. To
**consumer's root**, nie module's. Wzbudza implicit dependency na
strukturze plików konsumenta. Co jeśli ktoś używa quick-vm wewnątrz
sub-module — `path.root` jest GŁÓWNYM root, nie sub-module root.

**Fix:**

```hcl
variable "limits_output_dir" {
  type    = string
  default = null   # null = path.root/.qv-limits/ (current behavior)
}
```

Pozwala konsumentowi przekazać `limits_output_dir = "${path.module}/limits"`
lub absolutną ścieżkę. Backward-compatible (null = current default).

---

## Bigger features (worth considering, większy effort)

### 8. Ramp / interpolate mode

**Use case:** "Stopniowo dławić IO z 100 MB/s do 1 MB/s przez 5 minut —
sprawdzić gdzie aplikacja zaczyna się gubić" (chaos engineering progressive
degradation).

**Propozycja:** helper-script generowany przez `enable_live = true`
z dodatkowym fieldem:

```hcl
io.vda.ramp = optional(object({
  field    = string    # np. "write_bytes_sec"
  from     = number
  to       = number
  duration = string    # np. "5m"
  steps    = optional(number, 10)
}))
```

Generated `qv-limits.ramp.<vm>.sh`:
```bash
for step in $(seq 1 10); do
  value=$(calculate_value $from $to $step)
  sed -i "s/^write_bytes_sec.*/write_bytes_sec = $value/" qv-limits.spec.<vm>.ini
  bash qv-limits.apply.<vm>.sh
  sleep 30s
done
```

Zysk: deterministyczne A/B testowanie performance degradation.

### 9. Profile presets (`vm_profile.preset`)

**Problem:** dla typowych scenariuszy ("slow disk", "noisy neighbor",
"network constrained") trzeba wpisywać ręcznie 10-15 fields. Powtarzalne
przez wiele klastrów.

**Propozycja:** library presets:

```hcl
vm_profile.preset = optional(string)   # np. "slow-disk-hdd", "low-bandwidth-mobile"
```

Definicje w `modules/quick-vm/presets.tf`:

```hcl
locals {
  presets = {
    "slow-disk-hdd" = {
      io = {
        vda = {
          bytes_unit      = "MB"
          read_bytes_sec  = 50
          write_bytes_sec = 30
          read_iops_sec   = 100
          write_iops_sec  = 50
        }
      }
    }
    "low-bandwidth-mobile" = {
      network = {
        "0" = {
          rate_unit = "KB"
          inbound  = { average = 100, peak = 200 }
          outbound = { average = 50,  peak = 100 }
        }
      }
    }
    "throttled-25pct-cpu" = {
      cpu = { limit = { percent = 25 } }
    }
    # etc.
  }
}
```

User może `vm_profile.preset = "slow-disk-hdd"` zamiast 6 linii config.
Pozostałe pola `vm_profile.io.*` nadpisują preset (override).

### 10. Health check / readiness po apply limits

**Problem:** `qv-limits.apply.<vm>.sh` aplikuje limits, ale nie weryfikuje
czy faktycznie zostały zaaplowane. `virsh schedinfo` mógłby skrótem
sprawdzić.

**Propozycja:** dorzucić `--verify` flag do `apply.sh`:

```bash
bash qv-limits.apply.<vm>.sh --verify
# → po apply leci virsh schedinfo + virsh blkdeviotune + virsh domiftune
# → diff actual vs expected
# → exit 0 / 1
```

Zysk: chaos test pipeline może być `apply.sh --verify` (`set -e` friendly).

---

## Brakujące osie resource control (nie tylko bandwidth)

### 11. CPU pinning / affinity (`cpuset.cpus`)

**Fundamentalnie inna oś** niż `cpu.limit`. `limit.percent = 25` mówi
"VM może użyć max 25% CPU". `cpuset.cpus = "0-3"` mówi "VM może używać
TYLKO physical cores 0-3, nigdy 4+". Krytyczne dla:
- NUMA-aware workloads (przypisać VM do jednego NUMA node)
- Latency-sensitive apps (izolacja od noisy neighbor cores)
- Reproducible benchmarks (eliminate scheduler variance)

**Propozycja:**

```hcl
vm_profile.cpu.pin = optional(object({
  cpus = string         # np. "0-3", "0,2,4,6", "0-7,16-23"
  numa = optional(number)   # NUMA node, alternatywa do cpus
}))
```

Implementacja: `<cputune><vcpupin>` w XML + `virsh vcpupin` live.

### 12. NUMA topology

Twoja Stacja 7810 ma **2× Xeon E5-2680 v4** = dwa NUMA nodes. Bez NUMA
config VM może mieć vCPU na node 0 a memory na node 1 — cross-socket
traffic, ~2× latency penalty. Realne dla Cassandra/Kafka/ML workloads.

**Propozycja:**

```hcl
vm_profile.numa = optional(object({
  preferred_node    = optional(number)         # auto-allocate na tym node
  memory_strict     = optional(bool, false)    # hard binding
  cpu_node_mapping  = optional(map(string))    # vcpu0-3 → node 0, vcpu4-7 → node 1
}))
```

Implementacja: `<numatune>` + `<cpu><numa>` w XML.

### 13. Hugepages

Performance tuning dla aplikacji memory-intensive (DB, JVM heap, ML
training). Bez hugepages każdy memory access przechodzi przez TLB lookup
(4 KB pages). Z hugepages (2 MB lub 1 GB) — TLB hits znacznie częstsze.

**Propozycja:**

```hcl
vm_profile.memory_backing = {
  ...
  hugepages = optional(object({
    enabled  = bool
    page_size = optional(string, "2M")   # "2M" lub "1G"
  }))
}
```

(Można rozszerzyć obecny `memory_backing`, nie tworzyć osobnego pola.)

Wymaga że host ma pre-allocated hugepages (`sysctl vm.nr_hugepages`).

### 14. I/O priority (`blkio.weight`)

Soft priority dla dysku, analogiczny do CPU `shares`. Default 500
(zakres 100-1000). Pod contention, VM z weight 700 dostaje więcej IO
bandwidth niż VM z weight 300 — bez hard cap.

**Propozycja:**

```hcl
vm_profile.io.<dev>.weight = optional(number)   # 100-1000, default 500
```

Implementacja: `<iotune>` w XML lub `cgset` w sidecar.

---

## Operational concerns

### 15. Conflict resolution `enable_config` vs `enable_live`

**Problem:** jeśli oba są `true` i ustawiają **różne wartości** dla tego
samego pola (np. `cpu.limit.percent` różne w HCL vs `.ini`) — kto wygrywa?

Aktualnie:
- XML (enable_config) jest aplikowany przez `terraform apply`
- `.sh` (enable_live) overwriterzeuje przez `virsh schedinfo` natychmiast
- Po reboot VM wraca do XML state
- Po re-run `apply.sh` wraca do `.ini` state
- Race condition jeśli ktoś robi oba w tym samym czasie

**Fix:** zdokumentować precedence + dodać warning w `apply.sh` gdy
wykryje że `.ini` różni się od `vm_profile` w state.

### 16. Lifecycle: orphan files po destroy

**Problem:** `terraform destroy` usuwa VM, ALE `.qv-limits/<vm>.{ini,sh}`
zostają na dysku jako orphan files. Po N create+destroy cykli masz
zaśmiecony katalog.

**Fix:** dorzucić `local_file` lifecycle żeby cleanup był part of
destroy. Lub helper `cleanup-limits.sh` który grepuje przez current state.

### 17. State drift na editowanym `.ini`

**Problem:** user edytuje `.qv-limits/qv-limits.spec.<vm>.ini` ręcznie,
NIE odpala `apply.sh`. Terraform nie widzi zmiany. Następny apply
overwrite `.ini` z HCL value (bo `local_file` resource regeneruje).

**Fix:** dodać `lifecycle ignore_changes = [content]` na `local_file.limits_ini`
albo doc note "edits to .ini are not persistent across terraform apply
unless you also update vm_profile.* in HCL".

### 18. Multiple consumers — race condition

**Problem:** jeśli dwa Terraform projects deklarują limits dla TEJ SAMEJ
VM (mało prawdopodobne ale możliwe w multi-tenant Terraform), oba
generują `.ini` files w swoich `path.root/.qv-limits/`. Apply z drugiego
projektu nie wie o pierwszym. Klucz `quick_virt_version = "dev"` w `.ini`
ma być markerem, ale nie ma actual collision detection.

**Fix:** ostrzeżenie w doc + opcjonalnie `vm_profile.limits_owner = string`
dla audit (kto last applied).

---

## Cross-environment compatibility

### 19. cgroup v1 vs v2 paths

`apply.sh` używa `virsh schedinfo` / `virsh blkdeviotune` — abstract
z libvirt. To powinno działać na obu cgroup versions. **ALE** custom
sysfs writes (jeśli kiedyś dorzucimy memory limits, PID limits) mają
różne paths:

- cgroup v1: `/sys/fs/cgroup/memory/machine.slice/.../memory.limit_in_bytes`
- cgroup v2: `/sys/fs/cgroup/machine.slice/.../memory.max`

**Fix:** wykrywać `stat -c %T -f /sys/fs/cgroup` (`cgroup2fs` vs `tmpfs`)
i adaptować w skryptach.

### 20. Cross-distro testing matrix

**Problem:** quick-vm wspiera `os_name = ubuntu_22 | ubuntu_24 | rocky_9 | debian_12`.
Czy limits API faktycznie działa identycznie na każdym? Brak
dokumentowanej weryfikacji.

Konkretne obawy:
- Rocky 9 ma cgroup v2 by default, ale niektóre paths różne
- Debian 12 ma starszy kernel, niektóre `_max_length` mogą się nie aplikować
- Ubuntu 22 vs 24 — różne defaults w `vm.swappiness`, `kernel.panic`

**Fix:** dodać `examples/example6-vms-multi-os/` który próbuje limits
na każdym z 4 OS-ów. CI loop weryfikuje że `apply.sh --verify` zwraca
expected values.

---

## Observability

### 21. JSON output z `apply.sh`

**Problem:** obecnie `apply.sh` echo plain text (`[cpu] mode=PERCENT 25% × 2 vcpu...`).
Dla CI pipeline trudno parse. `--json` flag zwracający strukturyzowane
output byłby pomocny.

**Propozycja:** `bash apply.sh --json` → `{"cpu":{"mode":"PERCENT","quota_us":50000},"io":{...}}`
Lub osobny `qv-limits.show.<vm>.sh` który tylko czyta state.

### 22. Audit log

**Problem:** nie wiesz kto i kiedy zaaplował `.ini`. Multi-user lab
(team używa tej samej stacji) — brak provenance.

**Propozycja:** sidecar `qv-limits.history.<vm>.log` — każde wywołanie
`apply.sh` appendnuje `<timestamp> <USER> applied: <field>=<value>`.
Append-only, retention via logrotate.

---

## Provider compatibility

### 23. dmacvicar/libvirt 1.x roadmap

**Problem:** quick-vm pinuje provider `~> 0.9.0`. Gdy wyjdzie 1.0 (RC
prawdopodobnie w 2026), API może się zmienić:
- Multi-disk iotune support może być poprawiony (rozwiązuje #5)
- Nowe attrs dla NUMA i pinning
- Może breaking changes w `cpu_tune` field naming

**Fix:** śledzić https://github.com/dmacvicar/terraform-provider-libvirt/milestones
i przygotować migration path przy bump.

---

## Out of scope / Won't do (świadome wybory)

- **GPU/vGPU limits** — KVM passthrough, nie w naszej skali
- **Ballooning auto-tuning** — wymaga monitorowania pressure z guesta, complex
- **Per-cgroup runtime statistics scraping** — bardziej do monitoring tool
  (Prometheus libvirt exporter etc.)
- **Distributed throttle coordination** (np. "max combined IOPS across
  cluster") — to chaos-mesh territory, nie pojedynczy module
- **Real-time limit adaptation** (auto-throttle on host pressure) —
  feedback loop wymaga host monitor, scope-creep

---

## Priorytetyzacja (sugerowana kolejność)

**Tier 1 — najwyższy ROI (low effort, high impact):**
1. **Validation blocks** (#1) — najtańszy win, eliminuje frustrację
2. **Doc: shares + silent-fail mapa** (#2, #3) — clarity bez zmian API
3. **Conflict resolution doc** (#15) — wyjaśnić precedence `enable_config` vs `enable_live`
4. **Lifecycle: orphan files cleanup** (#16) — czystość po destroy
5. **State drift dokumentacja** (#17) — wyjaśnić co się dzieje przy edit `.ini`

**Tier 2 — większy functional gap:**
6. **CPU pinning / cpuset** (#11) — fundamentalnie inna oś, brak całkowicie
7. **Memory limits** (#4) — drugi biggest functional gap
8. **Hugepages** (#13) — performance tuning oczekiwany w prod-pattern
9. **Multi-disk native** (#5) — usuwa rozjazd między modes

**Tier 3 — niche ale wartościowe:**
10. **NUMA topology** (#12) — istotne na multi-socket hostach (twoja Stacja)
11. **I/O priority blkio.weight** (#14) — analogiczny do CPU shares dla dysku
12. **limits_output_dir** (#7) — szybki fix dla sub-module use case
13. **PID limits** (#6) — niche ale 5-linijkowa implementacja
14. **cgroup v1/v2 detection** (#19) — przygotowanie do memory/PID limits

**Tier 4 — quality-of-life / observability:**
15. **Ramp mode** (#8) — biggest UX win dla chaos engineering
16. **Profile presets** (#9) — quality-of-life
17. **`--verify` flag** (#10) — pipeline robustness
18. **JSON output** (#21) — CI/automation
19. **Audit log** (#22) — multi-user lab provenance
20. **Cross-distro testing matrix** (#20) — Rocky/Debian/Ubuntu compatibility CI

**Tier 5 — forward-looking:**
21. **Multiple consumers detection** (#18) — race condition warning
22. **dmacvicar/libvirt 1.x migration** (#23) — future-proof

---

## Verdict

API limitów to **najbogatsza feature quick-virt**, probably **najmniej
doceniona przez społeczność** (która jeszcze nie wie że istnieje). Realnie
to jedyne OSS narzędzie które daje cloud-provider-grade resource throttling
na self-hosted KVM. Każda z powyższych poprawek dociąga to do jeszcze
wyższego poziomu — ale rdzeń jest już prod-grade.

Trade-off do świadomości: dodawanie tych features = zwiększenie powierzchni
API. Już teraz `vm_profile` ma 40+ pól. Dorzucenie memory_limit, process_limit,
ramp, preset to ~50+ pól. Worth balancing z YAGNI — implementować na żądanie
(real use case), nie wszystko od razu.