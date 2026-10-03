# Setup v2 — from zero to a running VM

> **Status: DRAFT** — outline only. Each section will be expanded with commands,
> expected output, and troubleshooting. Order matters: steps 1–6 are the
> required path, steps 7–9 are optional features, 10–11 close the loop.

@REMARK spis treści

## 1. Host requirements

- Linux host — tested on **Ubuntu 24.04 LTS** (installer scripts are apt-based)
- CPU virtualization enabled in BIOS/UEFI (Intel VT-x / AMD-V)
  - quick check: `egrep -c '(vmx|svm)' /proc/cpuinfo` → must be > 0
  - full check (after step 3): `kvm-ok`
- Enough headroom: RAM and disk for the VMs you plan (base images ~600 MB each,
  default VM disk 20 GiB thin)
- Internet access — GitHub (installer), cloud-image mirrors (images)

## 2. Install the quick-virt CLI

@REMARK: Opisz krótko czym jest quick-virt....

- Install the [Task](https://taskfile.dev) runner first — quick-virt is a wrapper around it:
  - `sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin`
- Install quick-virt (no clone required):
  - `curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | bash`
  - pin a version with `QV_VERSION=vX.Y.Z`, track dev head with `QV_VERSION=main`
- Make sure `~/.local/bin` is on `PATH`
- Verify: `quick-virt self:version`, `quick-virt --list`
- Alternative: clone the repo and use `task` directly from the checkout

## 3. Install the KVM host stack

- `quick-virt setup:install-kvm`
  - installs qemu-kvm, libvirt, cloud-image tools, and module helpers (jq, xmllint, ipcalc)
  - adds your user to the `libvirt` and `kvm` groups
  - enables and starts `libvirtd`
- **Log out and back in** (or `newgrp libvirt`) so the group change takes effect
- Verify:
  - `virsh -c qemu:///system list --all` works **without sudo**
  - `kvm-ok` reports KVM acceleration can be used

## 4. Install Terraform

@REMARK: Przenieś do punkty 1 
- Not covered by the installer — install separately (>= 1.3; >= 1.9 recommended)
  - official apt repo / tenv / manual binary — TBD which to recommend
- Verify: `terraform version`
- Provider `dmacvicar/libvirt ~> 0.9` is pulled automatically by `terraform init`

## 5. Download OS cloud images

- One image: `quick-virt images:download:ubuntu22` (also: `ubuntu24`, `rocky9`, `debian12`)
- Everything: `quick-virt images:download:all`
- Verify: `quick-virt images:list` — status `downloaded` next to the image you need
- Images land in `/var/lib/libvirt/images/*.qcow2.base`


## 7. (Optional) Linux bridge — for `mode = "bridge"` networks
@REMARK  To musi być wcześniej
- Needed only when VMs should be reachable from the LAN
- Create: `quick-virt bridge:create PHYS_IF=<nic> BRIDGE_NAME=br0`
  - warning: reconfigures host networking — risky over remote/SSH sessions
- Check: `quick-virt bridge:status`
- Rollback: `quick-virt bridge:restore PHYS_IF=<nic> BRIDGE_NAME=br0`
- Without a bridge: keep bridge networks disabled in examples
  (`kvm_networks = { "...net-bridge" = { enabled = false } }`)


## 6. Create KVM networks (required before any VM)

@REMARK: Co wtedy jak  nie ma podłączenia bride i będziemy chieli utowrzyć właśnie te sieci?

- VM modules reference libvirt networks **by name** — the networks must exist first,
  otherwise `terraform apply` fails with *"network not found"*
- Fastest path — ready-made root:
  - `cd examples/prerequisites/01-networks-nat-bridge`
  - `terraform init && terraform apply -var-file=networks.tfvars` (or `./tf-apply.sh`)
- Alternative — scaffold your own project:
  - `quick-virt scaffold:init-networks DIR=./my-networks` then edit + apply
- Verify: `virsh net-list --all` shows the networks as active
- Inspect details anytime: `quick-virt net:info NET=<name>`



## 8. (Optional) NFS server — for `nfs_mounts`

- Install: `quick-virt setup:install-nfs-server`
- Export a directory to the VM network:
  - `quick-virt setup:configure-nfs-export DIR=/home/$USER/vm-shares CIDR=192.168.200.0/24`
  - the NAT gateway IP of the network **is** the host address VMs mount from
- Verify: `showmount -e localhost`

## 9. (Optional) Shared folders — for `shared_folders` (virtiofs / 9p)

- Check driver availability: `quick-virt setup:check-shared-folders-drivers`
- Install virtiofsd if missing: `quick-virt setup:install-virtiofsd`
- Grant qemu access to your files: `quick-virt setup:enable-shared-folders`
  - note: adds the `libvirt-qemu` user to **your** group — qemu can then read
    group-readable files in your home; undo with `setup:disable-shared-folders`

## 10. SSH key (for examples that inject one)

- Ensure `~/.ssh/id_rsa.pub` exists (`ssh-keygen` if not)
- Examples 03+ read it with `file("~/.ssh/id_rsa.pub")` and put it in cloud-init

## @REMARK co z default  storage pool - za proponuj 

## 11. Run the first VM

- Pick an example (see [`examples/README.md`](../examples/README.md)):
  - simplest start: `examples/02a-vm-network-variants`
- `terraform init && terraform apply`
- Verify the VM:
  - `virsh list` — VM running
  - `virsh console <name>` — login with the demo user/password from tfvars
  - or SSH to the static IP from the example
- Tear down: `terraform destroy` in the same directory

## @RERMARK dodaj opis jako korzystać z plików genenrowoanych  dla ssh
## @REMAARK dodaj opis jak korzystać  z plików  generowanych dla limitów (ale nie super szczegółowo  będzie sekcja)
## REMARK dodaj inne generowania  jeśli sa jak z nich  korzystaać
## 12. Troubleshooting / recovery (TBD — expand)

- *"network not found"* → step 6 not done, or network name typo
- `virsh` needs sudo → group change not active yet (re-login, step 3)
- permission denied on `/dev/kvm` → user not in `kvm` group / VT-x disabled
- stale/broken VM definitions → emergency reset: `quick-virt tools:clean-vms`
  - **warning: destructive** — removes ALL VM definitions *and* network
    definitions (by design, it is a recovery tool); re-apply step 6 afterwards
- networks only: `quick-virt tools:clean-networks`
- keep the CLI fresh: `quick-virt self:check-update` / `self:update`
