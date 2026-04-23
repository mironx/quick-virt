#!/bin/bash
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
    PKG="nfs-kernel-server"
    SVC="nfs-kernel-server"
    apt-get update -y -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$PKG"
elif command -v dnf >/dev/null 2>&1; then
    PKG="nfs-utils"
    SVC="nfs-server"
    dnf install -y "$PKG"
else
    echo "[error] Unsupported distribution — install an NFS server package manually." >&2
    exit 1
fi

systemctl enable --now "$SVC"

echo "[ok] NFS server ($PKG) installed and running."
echo
echo "Next step: configure an export, e.g."
echo "  task setup:configure-nfs-export DIR=/home/\$USER/vm-shares CIDR=192.168.100.0/24"