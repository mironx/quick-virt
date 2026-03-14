#!/bin/bash
#
# Test script for kvm-net-info.sh
# Runs various invocation scenarios and validates output.
# Stderr from kvm-net-info.sh is displayed for debugging.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KVM_NET_INFO="$SCRIPT_DIR/kvm-net-info.sh"
STDOUT_TMP=$(mktemp)
trap 'rm -f "$STDOUT_TMP"' EXIT

PASSED=0
FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() {
  PASSED=$((PASSED + 1))
  echo -e "  ${GREEN}PASS${NC}: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo -e "  ${RED}FAIL${NC}: $1"
  [ -n "${2:-}" ] && echo -e "        $2"
}

skip() {
  echo -e "  ${YELLOW}SKIP${NC}: $1"
}

# Run kvm-net-info.sh, capture stdout to STDOUT_TMP, let stderr pass through.
# Sets RUN_RC to the exit code.
# Usage: run_script <args...>
run_script() {
  RUN_RC=0
  echo -e "  ${CYAN}[input]${NC} mode=CLI, args: $*"
  echo -e "  ${CYAN}--- script output ---${NC}"
  "$KVM_NET_INFO" "$@" > "$STDOUT_TMP" 2>&1 || RUN_RC=$?
  while IFS= read -r line; do echo -e "  ${CYAN}|${NC} $line"; done < "$STDOUT_TMP"
  echo -e "  ${CYAN}--- end (exit=$RUN_RC) ---${NC}"
  local json_out
  json_out=$(get_json_output)
  if [ -n "$json_out" ]; then
    echo -e "  ${CYAN}[json output]${NC} $json_out"
  else
    echo -e "  ${CYAN}[json output]${NC} (none)"
  fi
}

# Same but with stdin piped
run_script_stdin() {
  local input="$1"
  RUN_RC=0
  echo -e "  ${CYAN}[input]${NC} mode=JSON stdin, payload: $input"
  echo -e "  ${CYAN}--- script output ---${NC}"
  echo "$input" | "$KVM_NET_INFO" > "$STDOUT_TMP" 2>&1 || RUN_RC=$?
  while IFS= read -r line; do echo -e "  ${CYAN}|${NC} $line"; done < "$STDOUT_TMP"
  echo -e "  ${CYAN}--- end (exit=$RUN_RC) ---${NC}"
  local json_out
  json_out=$(get_json_output)
  if [ -n "$json_out" ]; then
    echo -e "  ${CYAN}[json output]${NC} $json_out"
  else
    echo -e "  ${CYAN}[json output]${NC} (none)"
  fi
}

# Get stdout-only output (last line that is valid JSON)
get_json_output() {
  grep -E '^\{' "$STDOUT_TMP" | tail -1 || true
}

# Get non-JSON lines (stderr-like logs captured together)
get_log_output() {
  grep -vE '^\{' "$STDOUT_TMP" || true
}

# Check that kvm-net-info.sh exists and is executable
echo "=== Pre-checks ==="
if [ ! -x "$KVM_NET_INFO" ]; then
  echo "ERROR: $KVM_NET_INFO not found or not executable"
  exit 1
fi
echo "Script found: $KVM_NET_INFO"

# Get available networks
AVAILABLE_NETS=$(virsh net-list --name 2>/dev/null | grep -v '^$' || true)
if [ -z "$AVAILABLE_NETS" ]; then
  echo "ERROR: No KVM networks found. Cannot run tests."
  exit 1
fi
echo "Available networks: $(echo $AVAILABLE_NETS | tr '\n' ' ')"
echo ""

# Pick first NAT network for testing
NAT_NET=""
for net in $AVAILABLE_NETS; do
  mode=$(virsh net-dumpxml "$net" 2>/dev/null | xmllint --xpath "string(//forward/@mode)" - 2>/dev/null || echo "")
  if [[ "$mode" == "nat" ]]; then
    NAT_NET="$net"
    break
  fi
done

# Pick first bridge network for testing
BRIDGE_NET=""
for net in $AVAILABLE_NETS; do
  mode=$(virsh net-dumpxml "$net" 2>/dev/null | xmllint --xpath "string(//forward/@mode)" - 2>/dev/null || echo "")
  if [[ "$mode" == "bridge" ]]; then
    BRIDGE_NET="$net"
    break
  fi
done

# ---------------------------------------------------------------------------
echo "=== Test 1: CLI invocation with NAT network ==="
if [ -n "$NAT_NET" ]; then
  run_script "$NAT_NET"
  OUTPUT=$(get_json_output)

  if [ -n "$OUTPUT" ] && echo "$OUTPUT" | jq -e . > /dev/null 2>&1; then
    pass "Valid JSON returned"
  else
    fail "Output is not valid JSON" "$OUTPUT"
  fi

  MODE=$(echo "$OUTPUT" | jq -r .mode)
  if [[ "$MODE" == "nat" ]]; then
    pass "Mode is 'nat'"
  else
    fail "Expected mode 'nat', got '$MODE'"
  fi

  ERR=$(echo "$OUTPUT" | jq -r .error)
  if [[ "$ERR" == "" ]]; then
    pass "Field 'error' is empty (no error)"
  else
    fail "Expected empty error, got '$ERR'"
  fi

  for field in network mask_prefix mask_ip gateway; do
    val=$(echo "$OUTPUT" | jq -r ".$field")
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      pass "Field '$field' present: $val"
    else
      fail "Field '$field' missing or null"
    fi
  done
else
  skip "No NAT network available"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Test 2: JSON stdin invocation with NAT network ==="
if [ -n "$NAT_NET" ]; then
  run_script_stdin "{\"kvm_network_name\": \"$NAT_NET\"}"
  OUTPUT=$(get_json_output)

  if [ -n "$OUTPUT" ] && echo "$OUTPUT" | jq -e . > /dev/null 2>&1; then
    pass "Valid JSON returned via stdin"
  else
    fail "Output is not valid JSON" "$OUTPUT"
  fi

  MODE=$(echo "$OUTPUT" | jq -r .mode)
  if [[ "$MODE" == "nat" ]]; then
    pass "Mode is 'nat' (stdin)"
  else
    fail "Expected mode 'nat', got '$MODE'"
  fi
else
  skip "No NAT network available"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Test 3: Bridge network ==="
if [ -n "$BRIDGE_NET" ]; then
  BRIDGE_IFACE=$(virsh net-dumpxml "$BRIDGE_NET" 2>/dev/null | xmllint --xpath "string(//bridge/@name)" - 2>/dev/null || echo "")
  HAS_IP=$(ip -o -4 addr show "$BRIDGE_IFACE" 2>/dev/null | grep inet || true)

  if [ -n "$HAS_IP" ]; then
    run_script "$BRIDGE_NET"
    OUTPUT=$(get_json_output)

    if [ -n "$OUTPUT" ] && echo "$OUTPUT" | jq -e . > /dev/null 2>&1; then
      pass "Valid JSON returned for bridge network"
    else
      fail "Output is not valid JSON" "$OUTPUT"
    fi

    BRIDGE_VAL=$(echo "$OUTPUT" | jq -r .bridge)
    if [ -n "$BRIDGE_VAL" ] && [ "$BRIDGE_VAL" != "null" ]; then
      pass "Bridge field present: $BRIDGE_VAL"
    else
      fail "Bridge field missing for bridge mode"
    fi
  else
    echo "  Bridge '$BRIDGE_IFACE' has no IPv4 — testing graceful fallback..."
    run_script "$BRIDGE_NET"

    if [ "$RUN_RC" -eq 0 ]; then
      pass "Exit code 0 (graceful fallback)"
    else
      fail "Expected exit code 0 for graceful fallback, got $RUN_RC"
    fi

    OUTPUT=$(get_json_output)
    if [ -n "$OUTPUT" ] && echo "$OUTPUT" | jq -e . > /dev/null 2>&1; then
      pass "Valid JSON returned despite missing IPv4"
    else
      fail "Expected valid JSON fallback" "$OUTPUT"
    fi

    ERR=$(echo "$OUTPUT" | jq -r .error)
    if [ -n "$ERR" ]; then
      pass "Field 'error' present: $ERR"
    else
      fail "Expected non-empty error"
    fi
  fi
else
  skip "No bridge network available"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Test 4: Non-existent network ==="
run_script "nonexistent-net-xyz"

if [ "$RUN_RC" -ne 0 ]; then
  pass "Non-zero exit code for non-existent network"
else
  fail "Expected non-zero exit code for non-existent network"
fi

LOG_OUTPUT=$(get_log_output)
if echo "$LOG_OUTPUT" | grep -qi "failed\|error\|not found"; then
  pass "Output contains error info for non-existent network"
else
  fail "No useful error info for non-existent network" "$LOG_OUTPUT"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Test 5: Invalid JSON stdin ==="
run_script_stdin "not-json"

if [ "$RUN_RC" -ne 0 ]; then
  pass "Non-zero exit code for invalid JSON input"
else
  fail "Expected non-zero exit code for invalid JSON"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Test 6: JSON stdin missing kvm_network_name key ==="
run_script_stdin "{\"wrong_key\": \"value\"}"

if [ "$RUN_RC" -ne 0 ]; then
  pass "Non-zero exit code for missing kvm_network_name key"
else
  fail "Expected non-zero exit code for missing key"
fi

LOG_OUTPUT=$(get_log_output)
if echo "$LOG_OUTPUT" | grep -qi "kvm_network_name\|missing"; then
  pass "Output mentions missing key"
else
  fail "No useful error info for missing key" "$LOG_OUTPUT"
fi
echo ""

# ---------------------------------------------------------------------------
echo "=== Results ==="
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi