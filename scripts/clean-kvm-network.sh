#!/bin/bash
virsh net-list --all

virsh net-destroy local-network
virsh net-undefine local-network
virsh net-destroy bridge-network
virsh net-undefine bridge-network
sudo rm -f /var/lib/libvirt/network/local-network.xml
sudo rm -f /var/lib/libvirt/network/bridge-network.xml

virsh net-list --all
