#!/bin/bash
set -euo pipefail

DIR="${1:-}"
CIDR="${2:-}"
OPTIONS="${3:-rw,sync,no_subtree_check,no_root_squash}"
OWNER="${4:-}"

if [[ -z "$DIR" || -z "$CIDR" ]]; then
    cat <<'EOF' >&2
Usage: configure-nfs-export.sh <dir> <cidr> [options] [owner]

Arguments:
  <dir>      Absolute host path to export (e.g. /home/devx/vm-shares)
  <cidr>     Network allowed to mount, CIDR form (e.g. 192.168.100.0/24)
  [options]  NFS export options (default: rw,sync,no_subtree_check,no_root_squash)
  [owner]    user:group ownership for the directory (default: caller's user:group)
EOF
    exit 2
fi

if [[ "$DIR" != /* ]]; then
    echo "[error] <dir> must be an absolute path, got: $DIR" >&2
    exit 2
fi

if [[ -z "$OWNER" ]]; then
    REAL_USER="${SUDO_USER:-$(id -un)}"
    OWNER="${REAL_USER}:${REAL_USER}"
fi

mkdir -p "$DIR"
chown "$OWNER" "$DIR"
chmod 755 "$DIR"

ESCAPED_DIR=$(printf '%s\n' "$DIR" | sed 's/[\/&|]/\\&/g')
if grep -qE "^[[:space:]]*${ESCAPED_DIR}[[:space:]]" /etc/exports 2>/dev/null; then
    echo "[info] Replacing existing entry for $DIR in /etc/exports"
    sed -i "\|^[[:space:]]*${ESCAPED_DIR}[[:space:]]|d" /etc/exports
fi

echo "$DIR $CIDR($OPTIONS)" >> /etc/exports

exportfs -ra

echo "[ok] NFS export configured:"
echo "  $DIR  →  $CIDR($OPTIONS)   owner=$OWNER"
echo
echo "Current exports:"
exportfs -v