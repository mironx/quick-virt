#!/bin/bash
#
# Script Name: check-update.sh
#
# Description:
#   Best-effort "a newer version is available" notice for quick-virt. Designed to
#   run from the quick-virt wrapper without adding latency or breaking offline use.
#
# Modes:
#   compare  Offline & instant. Compares the installed .version against the cached
#            latest tag (written by 'refresh') and warns on stderr if a newer
#            release exists. Throttled to one notice per QV_NAG_TTL seconds.
#   refresh  Network. Refreshes the cached latest tag from GitHub, throttled to one
#            request per QV_UPDATE_TTL seconds. Safe to run in the background.
#   status   Network & synchronous. Always queries GitHub and prints installed vs
#            latest. Backs 'quick-virt self:check-update'.
#
# Env:
#   QV_UPDATE_TTL  Seconds between network refreshes (default 86400 = 24h).
#   QV_NAG_TTL     Seconds between repeated nags     (default 86400 = 24h).
#
# Cache files (only written for real installs, i.e. when .version exists):
#   <prefix>/.update-cache     "<epoch> <latest_tag>"  — written by refresh/status
#   <prefix>/.update-notified  "<epoch>"               — written by compare
#

set -euo pipefail

REPO="mironx/quick-virt"
UPDATE_TTL="${QV_UPDATE_TTL:-86400}"
NAG_TTL="${QV_NAG_TTL:-86400}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$PREFIX/.version"
CACHE_FILE="$PREFIX/.update-cache"
NOTIFY_FILE="$PREFIX/.update-notified"

now() { date +%s; }

is_semver() { [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

installed_version() {
  [ -f "$VERSION_FILE" ] || return 1
  tr -d '[:space:]' < "$VERSION_FILE"
}

# Latest semver tag from GitHub. Empty on failure/offline (5s timeout).
latest_tag() {
  curl -fsSL --max-time 5 "https://api.github.com/repos/${REPO}/tags" 2>/dev/null \
    | grep '"name"' \
    | sed -E 's/.*"name": "([^"]+)".*/\1/' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -1
}

# is_newer A B → true if B is strictly newer than A (both semver).
is_newer() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]
}

cmd_refresh() {
  [ -f "$VERSION_FILE" ] || return 0          # only for real installs — keep clones clean
  if [ -f "$CACHE_FILE" ]; then
    local ts; ts="$(cut -d' ' -f1 "$CACHE_FILE" 2>/dev/null || echo 0)"
    [ "$(( $(now) - ${ts:-0} ))" -lt "$UPDATE_TTL" ] && return 0
  fi
  local tag; tag="$(latest_tag || true)"
  [ -n "$tag" ] || return 0
  printf '%s %s\n' "$(now)" "$tag" > "$CACHE_FILE"
}

cmd_compare() {
  local inst latest
  inst="$(installed_version || true)"
  { [ -n "$inst" ] && is_semver "$inst"; } || return 0    # skip 'main'/unknown
  [ -f "$CACHE_FILE" ] || return 0
  latest="$(cut -d' ' -f2 "$CACHE_FILE" 2>/dev/null || true)"
  { [ -n "$latest" ] && is_semver "$latest"; } || return 0
  is_newer "$inst" "$latest" || return 0

  # throttle repeated nags
  if [ -f "$NOTIFY_FILE" ]; then
    local nts; nts="$(cut -d' ' -f1 "$NOTIFY_FILE" 2>/dev/null || echo 0)"
    [ "$(( $(now) - ${nts:-0} ))" -lt "$NAG_TTL" ] && return 0
  fi
  printf '%s\n' "$(now)" > "$NOTIFY_FILE" 2>/dev/null || true
  printf '[quick-virt] Update available: %s → %s. Run: quick-virt self:update\n' "$inst" "$latest" >&2
}

cmd_status() {
  local inst latest
  inst="$(installed_version || echo 'unknown')"
  latest="$(latest_tag || true)"
  if [ -z "$latest" ]; then
    echo "[warn] could not reach GitHub to check for updates (offline?)" >&2
    echo "installed: $inst"
    return 0
  fi
  [ -f "$VERSION_FILE" ] && printf '%s %s\n' "$(now)" "$latest" > "$CACHE_FILE"
  echo "installed: $inst"
  echo "latest   : $latest"
  if ! is_semver "$inst"; then
    echo "[note] installed version is not a release tag — cannot compare"
  elif [ "$inst" = "$latest" ]; then
    echo "[ok] up to date"
  elif is_newer "$inst" "$latest"; then
    echo "[update] newer version available — run: quick-virt self:update"
  else
    echo "[ok] ahead of latest published tag"
  fi
}

case "${1:-compare}" in
  compare) cmd_compare ;;
  refresh) cmd_refresh ;;
  status)  cmd_status ;;
  *) echo "usage: $(basename "$0") {compare|refresh|status}" >&2; exit 2 ;;
esac