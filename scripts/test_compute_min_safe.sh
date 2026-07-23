#!/usr/bin/env bash
#
# Unit tests for compute_min_safe_electron_major in update_security_rules.sh.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=update_security_rules.sh
source "${SCRIPT_DIR}/update_security_rules.sh"

TMP_DIR=""
PASS=0
FAIL=0

cleanup() {
    if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}
trap cleanup EXIT

TMP_DIR="$(mktemp -d)"

make_cve_json() {
    local ranges="$1"
    cat > "${TMP_DIR}/electron.json" <<EOF
[
  {
    "id": "TEST-001",
    "cveId": "TEST-001",
    "framework": "electron",
    "severity": "high",
    "summary": "Test entry",
    "affectedVersionRange": "${ranges}",
    "recordedAt": "2026-07-15"
  }
]
EOF
}

assert_eq() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "PASS: ${name} (expected=${expected}, actual=${actual})"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${name} (expected=${expected}, actual=${actual})" >&2
        FAIL=$((FAIL + 1))
    fi
}

# Test 1: pre-release suffix is parsed and major=41 is returned.
make_cve_json "< 41.0.0-beta.8"
assert_eq "pre-release suffix < 41.0.0-beta.8" "41" "$(compute_min_safe_electron_major "${TMP_DIR}/electron.json")"

# Test 2: plain 3-segment version returns major=38.
make_cve_json "< 38.8.6"
assert_eq "plain version < 38.8.6" "38" "$(compute_min_safe_electron_major "${TMP_DIR}/electron.json")"

# Test 3: mixed ranges and suffixes return the maximum major.
make_cve_json "< 38.8.6, < 41.0.0-beta.8, < 39.8.0"
assert_eq "mixed ranges max major" "41" "$(compute_min_safe_electron_major "${TMP_DIR}/electron.json")"

# Test 4: multiple entries across different objects are merged.
cat > "${TMP_DIR}/electron.json" <<'EOF'
[
  {
    "id": "TEST-001",
    "affectedVersionRange": "< 37.5.0, < 38.8.6",
    "recordedAt": "2026-07-15"
  },
  {
    "id": "TEST-002",
    "affectedVersionRange": "< 39.8.0, < 40.7.0, < 41.0.0-beta.8",
    "recordedAt": "2026-07-15"
  }
]
EOF
assert_eq "multiple entries merged" "41" "$(compute_min_safe_electron_major "${TMP_DIR}/electron.json")"

# Test 5: missing file falls back to 39.
rm -f "${TMP_DIR}/electron.json"
assert_eq "missing file fallback" "39" "$(compute_min_safe_electron_major "${TMP_DIR}/electron.json")"

echo "---"
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
