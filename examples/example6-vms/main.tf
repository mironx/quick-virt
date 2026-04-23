terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# ==============================================================================
# example6-vms — resource limits (CPU throttle + I/O throttle + burst)
#
# Two VMs to make side-by-side benchmarking easy:
#   - "loose"      → no limits (control baseline)
#   - "throttled"  → 25% CPU, 5/10 MB/s write/read, with burst spec in sidecar
#
# Inspect native libvirt tuning after apply:
#   virsh schedinfo qvms-ex6-throttled
#   virsh blkdeviotune qvms-ex6-throttled vda
#
# Apply live limits (including burst) at runtime — no reboot:
#   bash ./.qv-limits/qv-limits.apply.qvms-ex6-throttled.sh
# Clear every limit on one VM:
#   bash ./.qv-limits/qv-limits.clear.qvms-ex6-throttled.sh
# Whole 'workers' set at once:
#   bash ./.qv-limits/qv-limits.apply-all.qvms-ex6-worker.sh
#   bash ./.qv-limits/qv-limits.clear-all.qvms-ex6-worker.sh
# ==============================================================================

locals {
  prefix = "qvms-ex6"

  kvm_networks = {
    "qvexample-neta-loc-1" = { enabled = true }
    "qvexample-net-bridge" = { enabled = false }
  }

  user_data = templatefile("${path.module}/templates/user-data.tmpl", {
    user_name     = "ubuntu"
    user_password = "ubuntu123"
  })

  base_profile = {
    vcpu   = 2
    memory = 2048
  }
}

# ------------------------------------------------------------------------------
# VM #1 — "loose": no limits, serves as control/baseline for comparisons.
# ------------------------------------------------------------------------------
module "vm_loose" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-loose"
  os_name      = "ubuntu_22"
  user_data    = local.user_data
  vm_profile   = local.base_profile
  kvm-networks = local.kvm_networks
  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.90" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.90" }
  ]
}

# ------------------------------------------------------------------------------
# VM #2 — "throttled": CPU capped at 25%, disk I/O capped with burst allowance.
#
# Applied two ways:
#   enable_config = true   → baked into libvirt domain XML (cpu_tune, block_io_tune).
#                            Persists across VM reboots. No burst (provider limit).
#   enable_live   = true   → generates ./.qv-limits/<vm>.qv-limits.{ini,sh}.
#                            The .sh script applies EVERYTHING (incl. burst) live
#                            via virsh schedinfo + virsh blkdeviotune.
# ------------------------------------------------------------------------------
module "vm_throttled" {
  source       = "../../modules/quick-vm"
  name         = "${local.prefix}-throttled"
  os_name      = "ubuntu_22"
  user_data    = local.user_data
  kvm-networks = local.kvm_networks

  vm_profile = merge(local.base_profile, {
    cpu = {
      limit = {
        percent = 25           # 25% of total allocated CPU capacity (~0.5 of 2 vCPU)
      }
    }

    io = {
      vda = {
        bytes_unit = "MB"        # all *_bytes_sec* fields below are in MiB

        # Baseline — sustained throughput
        read_bytes_sec  = 10
        write_bytes_sec =  5
        read_iops_sec   = 1000
        write_iops_sec  = 500

        # Burst — short spikes above baseline
        read_bytes_sec_max          = 20           # 20 MiB/s peak
        read_bytes_sec_max_length   = 5            # for 5 seconds
        write_bytes_sec_max         = 10
        write_bytes_sec_max_length  = 5
        read_iops_sec_max           = 2000
        read_iops_sec_max_length    = 5
        write_iops_sec_max          = 1000
        write_iops_sec_max_length   = 5
      }
    }

    # Per-interface network bandwidth throttle (key = index in networks[])
    network = {
      "0" = {                                     # first interface (qvexample-neta-loc-1)
        rate_unit = "MB"                          # 1 MiB/s = 1024 KiB/s
        inbound = {
          average = 10                            #  10 MiB/s sustained download
          peak    = 50                            #  50 MiB/s burst peak
          burst   = 1                             #   1 MiB burst bucket
        }
        outbound = {
          average = 5                             #   5 MiB/s sustained upload
          peak    = 20
          burst   = 1
        }
      }
    }

    enable_config = true
    enable_live   = true
  })

  networks = [
    { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.91" },
    { profile_name = "qvexample-net-bridge", ip = "172.16.0.91" }
  ]
}

output "vms" {
  value = {
    loose = {
      name     = module.vm_loose.vm_name
      networks = module.vm_loose.vm_networks
      note     = "No CPU/I/O limits — reference baseline"
    }
    throttled = {
      name      = module.vm_throttled.vm_name
      networks  = module.vm_throttled.vm_networks
      note      = "CPU 25%, I/O 5/10 MB/s baseline + burst 10/20 MB/s for 5s"
      live_file = "./.qv-limits/qv-limits.apply.${module.vm_throttled.vm_name}.sh"
    }
  }
}

# ------------------------------------------------------------------------------
# VM set via quick-vms — 3 Ubuntu workers, all inheriting the same limits.
# Demonstrates that vm_profile.cpu.limit / io / enable_* apply per-set:
# every node (v1, v2, v3) gets the same throttles.
# ------------------------------------------------------------------------------
module "vms_workers" {
  source       = "../../modules/quick-vms"
  kvm-networks = local.kvm_networks

  machines = {
    workers = {
      set_name = "${local.prefix}-worker"
      os_name  = "ubuntu_22"

      vm_profile = {
        vcpu   = 2
        memory = 2048

        cpu = {
          limit = {
            percent = 50   # 50% of allocated CPU — moderate throttle per worker
          }
        }

        io = {
          vda = {
            bytes_unit = "MB"

            read_bytes_sec  = 20
            write_bytes_sec = 10
            read_iops_sec   = 2000
            write_iops_sec  = 1000

            # Burst allowance for short data spikes:
            write_bytes_sec_max        = 20
            write_bytes_sec_max_length = 10
          }
        }

        enable_config = true
        enable_live   = true
      }

      user = { name = "ubuntu", password = "ubuntu123" }
      cloud_init_user_data_path = "./templates/user-data.tmpl"

      nodes = [
        { name = "v1", networks = [
          { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.92" },
          { profile_name = "qvexample-net-bridge", ip = "172.16.0.92" },
        ] },
        { name = "v2", networks = [
          { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.93" },
          { profile_name = "qvexample-net-bridge", ip = "172.16.0.93" },
        ] },
        { name = "v3", networks = [
          { profile_name = "qvexample-neta-loc-1", ip = "192.168.200.94" },
          { profile_name = "qvexample-net-bridge", ip = "172.16.0.94" },
        ] },
      ]
    }
  }
}

output "workers" {
  value = module.vms_workers.vms_info
}