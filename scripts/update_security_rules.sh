#!/usr/bin/env bash
#
# Update FrameworkScanner security rules metadata.
# Usage:
#   scripts/update_security_rules.sh --date 2026-07-15 --version 2026.07.15 --stamp-cves
#
# This file can also be sourced by test scripts for the helper functions
# it defines (e.g. compute_min_safe_electron_major).
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANALYZER_FILE="${PROJECT_ROOT}/Sources/Services/SecurityAnalyzer.swift"
CVE_DIR="${PROJECT_ROOT}/Resources/CVE"

# Compute the minimum safe Electron major version from CVE data.
#
# It returns the highest fixed Electron major version referenced in
# Resources/CVE/electron.json (or 39 if no Electron CVEs exist).
# A version is recognized when it appears in an affectedVersionRange as
# "< X.Y.Z" or "< X.Y.Z-prerelease" (e.g. "< 41.0.0-beta.8").
#
# Args:
#   $1  Optional path to the Electron CVE JSON file. Defaults to
#       ${CVE_DIR}/electron.json.
compute_min_safe_electron_major() {
    local electron_cve_file="${1:-${CVE_DIR}/electron.json}"
    local max_major=0
    if [[ -f "${electron_cve_file}" ]]; then
        # Extract version strings from affectedVersionRange values.
        # Supported forms: "< X.Y.Z" and "< X.Y.Z-beta.N" (or any
        # alphanumeric/dot pre-release suffix).
        local ranges
        ranges="$(grep -oE '< [0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?' "${electron_cve_file}" | sed 's/^< //' || true)"
        while IFS= read -r ver; do
            [[ -z "${ver}" ]] && continue
            local major
            major="$(echo "${ver}" | cut -d. -f1)"
            if [[ "${major}" =~ ^[0-9]+$ && "${major}" -gt "${max_major}" ]]; then
                max_major="${major}"
            fi
        done <<< "${ranges}"
    fi
    if [[ "${max_major}" -gt 0 ]]; then
        echo "${max_major}"
    else
        echo "39"
    fi
}

# Everything below only runs when this script is executed directly.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

DATE=""
VERSION=""
THRESHOLD=""
STAMP_CVE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --date DATE          Security rules last reviewed date (YYYY-MM-DD)
  --version VERSION    Security rules version (YYYY.MM.DD)
  --threshold DAYS     Reminder threshold days (default: keep existing)
  --stamp-cves         Update recordedAt for all CVE entries to DATE
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date)
            DATE="${2:-}"
            shift 2
            ;;
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --threshold)
            THRESHOLD="${2:-}"
            shift 2
            ;;
        --stamp-cves)
            STAMP_CVE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "${DATE}" || -z "${VERSION}" ]]; then
    echo "Error: --date and --version are required." >&2
    usage >&2
    exit 1
fi

if [[ ! "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: --date must be in YYYY-MM-DD format." >&2
    exit 1
fi

if [[ ! "${VERSION}" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
    echo "Error: --version must be in YYYY.MM.DD format." >&2
    exit 1
fi

if [[ ! -f "${ANALYZER_FILE}" ]]; then
    echo "Error: SecurityAnalyzer.swift not found at ${ANALYZER_FILE}" >&2
    exit 1
fi

MIN_SAFE_ELECTRON_MAJOR="$(compute_min_safe_electron_major)"

# Update metadata constants in SecurityAnalyzer.swift.
sed -i.bak \
    -e "s/private static let securityRulesVersion = \"[^\"]*\"/private static let securityRulesVersion = \"${VERSION}\"/" \
    -e "s/private static let securityRulesLastReviewedAt = \"[^\"]*\"/private static let securityRulesLastReviewedAt = \"${DATE}\"/" \
    -e "s/private static let minSafeElectronMajor = [0-9]*/private static let minSafeElectronMajor = ${MIN_SAFE_ELECTRON_MAJOR}/" \
    "${ANALYZER_FILE}"

if [[ -n "${THRESHOLD}" ]]; then
    if [[ ! "${THRESHOLD}" =~ ^[0-9]+$ ]]; then
        echo "Error: --threshold must be a positive integer." >&2
        exit 1
    fi
    sed -i.bak \
        -e "s/private static let securityRulesReminderThresholdDays = [0-9]*/private static let securityRulesReminderThresholdDays = ${THRESHOLD}/" \
        "${ANALYZER_FILE}"
fi

rm -f "${ANALYZER_FILE}.bak"

# Optionally stamp recordedAt for all CVE entries.
if [[ "${STAMP_CVE}" == true ]]; then
    if [[ ! -d "${CVE_DIR}" ]]; then
        echo "Error: CVE directory not found at ${CVE_DIR}" >&2
        exit 1
    fi

    python3 - "${CVE_DIR}" "${DATE}" <<'PY'
import json
import os
import sys

cve_dir = sys.argv[1]
stamp_date = sys.argv[2]

for filename in sorted(os.listdir(cve_dir)):
    if not filename.endswith('.json'):
        continue
    filepath = os.path.join(cve_dir, filename)
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        print(f'Warning: skipping {filename}', file=sys.stderr)
        continue

    if not isinstance(data, list):
        continue

    changed = False
    for entry in data:
        if isinstance(entry, dict):
            entry['recordedAt'] = stamp_date
            changed = True

    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
PY
fi

echo "Security rules metadata updated: version=${VERSION}, date=${DATE}, minSafeElectronMajor=${MIN_SAFE_ELECTRON_MAJOR}"
if [[ "${STAMP_CVE}" == true ]]; then
    echo "CVE recordedAt stamped to ${DATE}."
fi
