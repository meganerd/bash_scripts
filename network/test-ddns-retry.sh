#!/usr/bin/env bash
# test-ddns-retry.sh — Tests for ddns-retry.sh
#
# Runs shellcheck and functional tests with mock data.
# Usage: ./test-ddns-retry.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DDNS_RETRY="${SCRIPT_DIR}/ddns-retry.sh"
PASS=0
FAIL=0
TMPDIR_TEST=""

# shellcheck disable=SC2317
cleanup() {
    if [[ -n "${TMPDIR_TEST}" && -d "${TMPDIR_TEST}" ]]; then
        rm -rf "${TMPDIR_TEST}"
    fi
}
trap cleanup EXIT

TMPDIR_TEST="$(mktemp -d)"
TEST_LOG="${TMPDIR_TEST}/test.log"

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
    [[ -n "${2:-}" ]] && echo "        $2"
}

assert_exit() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    if [[ "${actual}" -eq "${expected}" ]]; then
        pass "${test_name}"
    else
        fail "${test_name}" "expected exit ${expected}, got ${actual}"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        pass "${test_name}"
    else
        fail "${test_name}" "output does not contain '${needle}'"
    fi
}

# --- Shellcheck ---
echo "=== Shellcheck ==="
if shellcheck "${DDNS_RETRY}"; then
    pass "shellcheck clean"
else
    fail "shellcheck had warnings or errors"
fi

# --- Help flag ---
echo ""
echo "=== Help flag ==="
output=$("${DDNS_RETRY}" --help 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "Usage:" "--help shows usage"
assert_exit 0 "${rc}" "--help exits 0"

# --- Missing leases file ---
echo ""
echo "=== Missing leases file ==="
output=$("${DDNS_RETRY}" --leases-file "/nonexistent/file" --key-file "${TMPDIR_TEST}/fake.key" --log-file "${TEST_LOG}" 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "Leases file not found" "reports missing leases file"
assert_exit 1 "${rc}" "exits 1 on missing leases file"

# --- Missing key file ---
echo ""
echo "=== Missing key file ==="
cat > "${TMPDIR_TEST}/dummy.leases" <<'EOF'
lease 192.168.77.255 {
  starts 1 2026/07/27 10:05:35;
  ends 2 2026/07/28 10:05:35;
  binding state active;
  hardware ethernet 34:5a:60:c5:d8:12;
  client-hostname "motivity-one";
  set ddns-fwd-name = "motivity-one.zarquon.space.";
}
EOF
output=$("${DDNS_RETRY}" --leases-file "${TMPDIR_TEST}/dummy.leases" --key-file "/nonexistent/key" --log-file "${TEST_LOG}" 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "TSIG key file not found" "reports missing key file"
assert_exit 1 "${rc}" "exits 1 on missing key file"

# --- Empty leases file ---
echo ""
echo "=== Empty leases file ==="
cat > "${TMPDIR_TEST}/empty.leases" <<'EOF'
EOF
cat > "${TMPDIR_TEST}/test.key" <<'EOF'
key DDNS_RETRY {
    algorithm hmac-md5;
    secret "AAAAAA==";
};
EOF
output=$("${DDNS_RETRY}" --leases-file "${TMPDIR_TEST}/empty.leases" --key-file "${TMPDIR_TEST}/test.key" --dns-server "127.0.0.1" --external-server "127.0.0.1" --log-file "${TEST_LOG}" 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "total=0" "reports zero leases"
assert_exit 0 "${rc}" "exits 0 with no leases"

# --- Lease parsing ---
echo ""
echo "=== Lease parsing ==="
cat > "${TMPDIR_TEST}/multi.leases" <<'EOF'
lease 192.168.77.255 {
  starts 1 2026/07/27 10:05:35;
  ends 2 2026/07/28 10:05:35;
  binding state active;
  hardware ethernet 34:5a:60:c5:d8:12;
  client-hostname "motivity-one";
  set ddns-fwd-name = "motivity-one.zarquon.space.";
}
lease 192.168.76.141 {
  starts 1 2026/07/27 10:00:00;
  ends 2 2026/07/28 10:00:00;
  binding state free;
  hardware ethernet aa:bb:cc:dd:ee:ff;
  client-hostname "old-host";
  set ddns-fwd-name = "old-host.zarquon.space.";
}
lease 192.168.76.124 {
  starts 1 2026/07/27 11:00:00;
  ends 2 2026/07/28 11:00:00;
  binding state active;
  hardware ethernet 11:22:33:44:55:66;
  client-hostname "mi-cm4-4c";
  set ddns-fwd-name = "mi-cm4-4c.lan.meganerd.ca";
}
EOF
output=$("${DDNS_RETRY}" --leases-file "${TMPDIR_TEST}/multi.leases" --key-file "${TMPDIR_TEST}/test.key" --dns-server "127.0.0.1" --external-server "127.0.0.1" --dry-run --log-file "${TEST_LOG}" 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "total=2" "active leases with ddns-fwd-name counted, free lease excluded"

# --- Dry run mode ---
echo ""
echo "=== Dry run mode ==="
output=$("${DDNS_RETRY}" --leases-file "${TMPDIR_TEST}/dummy.leases" --key-file "${TMPDIR_TEST}/test.key" --dns-server "127.0.0.1" --external-server "127.0.0.1" --dry-run --log-file "${TEST_LOG}" 2>&1) && rc=$? || rc=$?
assert_contains "${output}" "DRY-RUN" "dry run produces DRY-RUN output"
assert_exit 0 "${rc}" "dry run exits 0"

# --- Custom log file ---
echo ""
echo "=== Custom log file ==="
CUSTOM_LOG="${TMPDIR_TEST}/custom.log"
"${DDNS_RETRY}" --leases-file "${TMPDIR_TEST}/empty.leases" --key-file "${TMPDIR_TEST}/test.key" --log-file "${CUSTOM_LOG}" --dns-server "127.0.0.1" --external-server "127.0.0.1" 2>&1 || true
if [[ -f "${CUSTOM_LOG}" ]]; then
    pass "custom log file created"
else
    fail "custom log file not created"
fi

# --- Summary ---
echo ""
echo "==========================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==========================="

if (( FAIL > 0 )); then
    exit 1
fi
exit 0
