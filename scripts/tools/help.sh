#!/bin/bash
#
# help.sh — grouped, example-driven quick reference for quick-virt.
#   Ordered from must-have install, through configuration, to tools and self-management.
#   More readable than `task --list`. Colors auto-disable when output isn't a TTY.
#

set -euo pipefail

if [ -t 1 ]; then
  B=$'\033[1m'; C=$'\033[36m'; D=$'\033[2m'; R=$'\033[0m'
else
  B=''; C=''; D=''; R=''
fi

# Use 'quick-virt' when installed on PATH, otherwise 'task' (running from a clone).
CMD="quick-virt"
command -v quick-virt >/dev/null 2>&1 || CMD="task"

hdr() { printf '\n%s%s%s\n' "$B" "$1" "$R"; }
row() { printf '  %s%-30s%s %s\n' "$C" "$1" "$R" "$2"; }   # bare command + description
ex()  { printf '       %se.g. %s%s\n' "$D" "$1" "$R"; }    # dim example line
note(){ printf '  %s%s%s\n' "$D" "$1" "$R"; }

printf '%squick-virt%s — quick KVM virtual machines on Linux (Terraform + Task)\n' "$B" "$R"
printf 'Usage: %s%s <command> [VAR=value ...]%s   ·   commands below are shown without the leading "%s"\n' \
  "$C" "$CMD" "$R" "$CMD"

hdr "First run (zero → running VM)"
note "0. Install Task first → https://taskfile.dev/installation/"
note "   sh -c \"\$(curl --location https://taskfile.dev/install.sh)\" -- -d -b ~/.local/bin"
note "1. $CMD setup:install-kvm                 # KVM + libvirt (once per host)"
note "2. $CMD images:download:ubuntu22          # an OS cloud image"
note "3. $CMD scaffold:init-networks DIR=./net  # then: cd net && terraform init && terraform apply"
note "4. apply a VM example (examples/example3a-vm) or use the quick-vm module"

hdr "1. Host setup — must have"
row "setup:install-kvm"                "Install KVM, libvirt and helpers (run first)"
row "setup:install-virtiofsd"          "Install virtiofsd (for virtiofs shared folders)"
row "setup:check-shared-folders-drivers" "Check virtiofs / 9p driver availability"
row "setup:install-nfs-server"         "Install + enable the NFS server"

hdr "2. OS images"
row "images:list"                      "List images and download status"
row "images:download:ubuntu22"         "Download Ubuntu 22.04"
ex  "$CMD images:download:ubuntu24   (also :rocky9  :debian12  :all)"
row "images:remove:ubuntu22"           "Remove one image (also :all)"

hdr "3. Networks & Linux bridge"
row "net:info NET=<name>"              "Show CIDR / gateway / DHCP of a libvirt network"
ex  "$CMD net:info NET=qvexample-neta-loc-1"
row "bridge:status"                    "Show bridge status (all, or BRIDGE=br0 for one)"
row "bridge:create"                    "Create a bridge bound to a physical NIC"
ex  "$CMD bridge:create PHYS_IF=enp0s31f6 BRIDGE_NAME=br0"
row "bridge:restore"                   "Tear down the bridge, restore plain DHCP"
ex  "$CMD bridge:restore PHYS_IF=enp0s31f6 BRIDGE_NAME=br0"

hdr "4. Configuration — shared folders & NFS"
row "setup:enable-shared-folders"      "Let QEMU read your files (your user)"
row "setup:enable-shared-folders-for"  "Same, for a specific user (USER=...)"
ex  "$CMD setup:enable-shared-folders-for USER=devx"
row "setup:disable-shared-folders"     "Roll back shared-folder access"
row "setup:configure-nfs-export"       "Add an NFS export (DIR, CIDR required)"
ex  "$CMD setup:configure-nfs-export DIR=/home/you/vm-shares CIDR=192.168.100.0/24"

hdr "5. Scaffolding"
row "scaffold:init-networks"           "Scaffold a Terraform KVM-networks project"
ex  "$CMD scaffold:init-networks DIR=./net"
row "scaffold:init-cloud-config"       "Create a cloud-init user-data template"
ex  "$CMD scaffold:init-cloud-config DIR=./templates"

hdr "6. Tools — cleanup (destructive)"
row "tools:clean-vms"                  "Destroy & undefine ALL libvirt VMs"
row "tools:clean-networks"             "Destroy ALL libvirt networks"

hdr "7. Manage quick-virt itself"
row "self:version"                     "Show installed version"
row "self:check-update"                "Check GitHub for a newer version"
row "self:update"                      "Re-install latest (QV_VERSION=<tag> to pin)"
row "self:where"                       "Show install paths"
row "self:uninstall"                   "Remove the installation"

hdr "More"
row "--list"                           "Full, flat list of every task"
note "Full reference with examples → doc/QUICK-VIRT.md"
printf '\n'
