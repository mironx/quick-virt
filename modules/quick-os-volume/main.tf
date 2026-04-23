terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
  }
}

//-------------------------------------------------------------------------------
// OS profiles (same as quick-vm)
//-------------------------------------------------------------------------------

locals {
  os_profiles = {
    ubuntu_22 = {
      image_local      = "/var/lib/libvirt/images/ubuntu-2204.qcow2.base"
      image_url        = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
    ubuntu_24 = {
      image_local      = "/var/lib/libvirt/images/ubuntu-2404.qcow2.base"
      image_url        = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
    rocky_9 = {
      image_local      = "/var/lib/libvirt/images/rocky-9.qcow2.base"
      image_url        = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
      network_template = "networkmanager"
      interface_naming = "eth"
      interface_offset = 0
      fs_type          = "virtiofs"
    }
    debian_12 = {
      image_local      = "/var/lib/libvirt/images/debian-12.qcow2.base"
      image_url        = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      network_template = "netplan"
      interface_naming = "enp0s"
      interface_offset = 3
      fs_type          = "virtiofs"
    }
  }

  _builtin_os = local.os_profiles[coalesce(var.os_name, "ubuntu_22")]

  selected_os = var.os_profile != null ? {
    image            = var.os_profile.image
    network_template = var.os_profile.network_template
    interface_naming = var.os_profile.interface_naming
    interface_offset = try(var.os_profile.interface_offset, 3)
    fs_type          = try(var.os_profile.fs_type, "virtiofs")
  } : {
    image            = var.os_image_mode == "local" ? local._builtin_os.image_local : local._builtin_os.image_url
    network_template = local._builtin_os.network_template
    interface_naming = local._builtin_os.interface_naming
    interface_offset = local._builtin_os.interface_offset
    fs_type          = local._builtin_os.fs_type
  }
}

//-------------------------------------------------------------------------------
// Base volume
//-------------------------------------------------------------------------------

resource "libvirt_volume" "base" {
  name = "qv-base-${var.volume_name}.qcow2"
  pool = var.storage_pool
  create = {
    content = {
      url = local.selected_os.image
    }
  }
  target = {
    format = {
      type = "qcow2"
    }
  }
}