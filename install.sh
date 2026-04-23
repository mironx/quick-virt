#!/bin/bash
# quick-virt installer — downloads the latest tagged CLI payload without cloning the repo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | QV_VERSION=v0.1.8 bash
#   curl -fsSL https://raw.githubusercontent.com/mironx/quick-virt/main/install.sh | QV_VERSION=main bash
#
# Env vars:
#   QV_VERSION  Tag (v0.1.8) or branch (main). Default: latest tag resolved via GitHub API.
#   QV_PREFIX   Install location.        Default: ~/.local/share/quick-virt
#   QV_BIN      Wrapper binary location. Default: ~/.local/bin

set -euo pipefail

REPO="mironx/quick-virt"
PREFIX="${QV_PREFIX:-$HOME/.local/share/quick-virt}"
BIN_DIR="${QV_BIN:-$HOME/.local/bin}"

info()  { printf '[*] %s\n' "$*"; }
ok()    { printf '[ok] %s\n' "$*"; }
warn()  { printf '[warn] %s\n' "$*" >&2; }
die()   { printf '[error] %s\n' "$*" >&2; exit 1; }

get_latest_tag() {
    curl -fsSL "https://api.github.com/repos/${REPO}/tags" 2>/dev/null \
      | grep '"name"' \
      | sed -E 's/.*"name": "([^"]+)".*/\1/' \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -V | tail -1
}

# ---------------------------------------------------------------- resolve version
QV_VERSION="${QV_VERSION:-}"
if [ -z "$QV_VERSION" ]; then
    info "Resolving latest tag from GitHub..."
    QV_VERSION="$(get_latest_tag || true)"
    if [ -z "$QV_VERSION" ]; then
        warn "Could not fetch tags (rate-limit or offline) — falling back to 'main'"
        QV_VERSION="main"
    fi
fi

if [[ "$QV_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${QV_VERSION}.tar.gz"
else
    ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${QV_VERSION}.tar.gz"
fi

info "Installing quick-virt ${QV_VERSION}"
info "Prefix : ${PREFIX}"
info "Binary : ${BIN_DIR}/quick-virt"

# ---------------------------------------------------------------- download + extract
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$ARCHIVE_URL" -o "$tmp/archive.tar.gz" \
    || die "Failed to download ${ARCHIVE_URL}"

# Strip the top-level 'quick-virt-<ref>/' prefix and keep only the CLI bits:
#   - Taskfile.yml
#   - scripts/
#   - modules/quick-kvm-network-reader/scripts  (needed by the 'net:info' task)
tar -xz -C "$tmp" -f "$tmp/archive.tar.gz" \
    --strip-components=1 \
    --wildcards \
    '*/Taskfile.yml' \
    '*/scripts' \
    '*/modules/quick-kvm-network-reader/scripts' \
    || die "Tarball extraction failed"

# ---------------------------------------------------------------- install
mkdir -p "$PREFIX" "$BIN_DIR"
rm -rf "$PREFIX/Taskfile.yml" "$PREFIX/scripts" "$PREFIX/modules"

cp    "$tmp/Taskfile.yml" "$PREFIX/Taskfile.yml"
cp -r "$tmp/scripts"      "$PREFIX/scripts"
mkdir -p "$PREFIX/modules/quick-kvm-network-reader"
cp -r "$tmp/modules/quick-kvm-network-reader/scripts" \
      "$PREFIX/modules/quick-kvm-network-reader/scripts"

echo "$QV_VERSION" > "$PREFIX/.version"

cat > "$BIN_DIR/quick-virt" <<EOF
#!/bin/bash
exec task -t "$PREFIX/Taskfile.yml" "\$@"
EOF
chmod +x "$BIN_DIR/quick-virt"

ok "quick-virt ${QV_VERSION} installed."

# ---------------------------------------------------------------- post-install hints
case ":$PATH:" in
    *:"$BIN_DIR":*) ;;
    *)
        printf '\n'
        warn "${BIN_DIR} is not on your PATH."
        printf '       Add to your shell profile (~/.bashrc or ~/.zshrc):\n'
        printf '         export PATH="%s:$PATH"\n' "$BIN_DIR"
        ;;
esac

if ! command -v task >/dev/null 2>&1; then
    printf '\n'
    warn "'task' runner is not installed — install it first:"
    printf '         sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin\n'
    printf '       or see https://taskfile.dev/installation/\n'
fi

cat <<'EOF'

Quick start:
  quick-virt --list
  quick-virt setup:install-kvm
  quick-virt setup:install-nfs-server
  quick-virt self:version
  quick-virt self:update       # re-install latest tag
  quick-virt self:uninstall    # remove
EOF