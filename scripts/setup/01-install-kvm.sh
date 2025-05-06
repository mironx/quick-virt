#!/bin/bash


sudo apt update

# 1. Install KVM and related packages
sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  virt-manager \
  cloud-image-utils \
  genisoimage \
  cloud-init \
  net-tools

# 2. Check if KVM is supported
sudo usermod -aG libvirt,kvm $(whoami)
newgrp libvirt
newgrp kvm


# check libvirt service:
# sudo systemctl status libvirtd

# 3. Install other packages for modules like quick-kvm-network-reader
sudo apt install -y jq libxml2-utils ipcalc
