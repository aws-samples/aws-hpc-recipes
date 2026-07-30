#!/bin/bash
# validate.sh — Validation script for pcs-scripts/node_lifecycle_demo recipe
#
# Runs automated checks suitable for CI. The top-level `make validate` and the
# repository CI pipeline do not lint shell scripts or check partition safety in
# .sh files, so this recipe validates its own scripts here.
#
# Exit codes: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECIPE_DIR="$(dirname "${SCRIPT_DIR}")"
ASSETS_DIR="${RECIPE_DIR}/assets"
ERRORS=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }

# Collect the shell scripts under assets/ plus this validator.
# Use a while-read loop rather than `mapfile` so this runs on bash 3.2 (macOS).
ASSET_SCRIPTS=()
while IFS= read -r line; do
    ASSET_SCRIPTS+=("${line}")
done < <(find "${ASSETS_DIR}" -maxdepth 1 -name '*.sh' | sort)
ALL_SCRIPTS=("${ASSET_SCRIPTS[@]}" "${SCRIPT_DIR}/validate.sh")

###############################################################################
# Check 1: Shell script syntax (bash -n)
###############################################################################
echo "Check 1: Shell script syntax (bash -n)"
for script in "${ALL_SCRIPTS[@]}"; do
    if bash -n "${script}" 2>/dev/null; then
        pass "$(basename "${script}") — syntax OK"
    else
        fail "$(basename "${script}") — syntax error"
    fi
done

###############################################################################
# Check 2: ShellCheck linting
###############################################################################
echo "Check 2: ShellCheck linting"
if command -v shellcheck >/dev/null 2>&1; then
    for script in "${ALL_SCRIPTS[@]}"; do
        if shellcheck "${script}" >/dev/null 2>&1; then
            pass "$(basename "${script}") — ShellCheck OK"
        else
            fail "$(basename "${script}") — ShellCheck warnings/errors"
        fi
    done
else
    echo "  ⚠ ShellCheck not installed — skipping"
fi

###############################################################################
# Check 3: Metadata schema (required fields)
###############################################################################
echo "Check 3: Metadata schema"
METADATA="${RECIPE_DIR}/metadata.yml"
for field in "name:" "version:" "description:" "tags:" "type:"; do
    if grep -q "${field}" "${METADATA}"; then
        pass "metadata.yml contains ${field}"
    else
        fail "metadata.yml missing ${field}"
    fi
done

###############################################################################
# Check 4: Partition safety (no hardcoded arn:aws: or amazonaws.com)
###############################################################################
echo "Check 4: Partition safety"
# Scan shell scripts and JSON assets. The public HPC Recipes S3 host
# (aws-hpc-recipes.s3.<region>.amazonaws.com) is an expected reference and is
# allowed; anything else that hardcodes a partition or the AWS domain fails.
SCAN_FILES=()
while IFS= read -r line; do
    SCAN_FILES+=("${line}")
done < <(find "${ASSETS_DIR}" -maxdepth 1 \( -name '*.sh' -o -name '*.json' \) | sort)
for file in "${SCAN_FILES[@]}"; do
    filename="$(basename "${file}")"

    if grep -n "arn:aws:" "${file}" | grep -v "AWS::Partition" | grep -v "^[0-9]*:#" > /dev/null 2>&1; then
        fail "${filename} — contains hardcoded arn:aws:"
    else
        pass "${filename} — no hardcoded arn:aws:"
    fi

    if grep -n "amazonaws.com" "${file}" | grep -v "AWS::URLSuffix" | grep -v "^[0-9]*:#" | grep -v "aws-hpc-recipes.s3" | grep -v "169.254.169.254" > /dev/null 2>&1; then
        fail "${filename} — contains hardcoded amazonaws.com"
    else
        pass "${filename} — no hardcoded amazonaws.com"
    fi
done

###############################################################################
# Check 5: Checksums present and current
###############################################################################
echo "Check 5: Script checksums"
if command -v sha256sum >/dev/null 2>&1; then
    HASH_CMD="sha256sum"
else
    HASH_CMD="shasum -a 256"
fi
for script in "${ASSET_SCRIPTS[@]}"; do
    checksum_file="${script}.sha256"
    filename="$(basename "${script}")"
    if [[ ! -f "${checksum_file}" ]]; then
        fail "${filename} — missing companion .sha256"
        continue
    fi
    recorded="$(awk '{print $1}' "${checksum_file}")"
    actual="$(${HASH_CMD} "${script}" | awk '{print $1}')"
    if [[ "${recorded}" == "${actual}" ]]; then
        pass "${filename} — checksum current"
    else
        fail "${filename} — checksum stale (run 'make checksums')"
    fi
done

###############################################################################
# Check 6: Example lifecycle-actions JSON is valid
###############################################################################
echo "Check 6: Example JSON validity"
EXAMPLE_JSON="${ASSETS_DIR}/example-node-lifecycle-actions.json"
if [[ -f "${EXAMPLE_JSON}" ]]; then
    if python3 -m json.tool "${EXAMPLE_JSON}" >/dev/null 2>&1; then
        pass "example-node-lifecycle-actions.json — valid JSON"
    else
        fail "example-node-lifecycle-actions.json — invalid JSON"
    fi
else
    fail "example-node-lifecycle-actions.json — missing"
fi

###############################################################################
# Summary
###############################################################################
echo ""
if [[ ${ERRORS} -eq 0 ]]; then
    echo "All checks passed."
    exit 0
else
    echo "FAILED: ${ERRORS} check(s) failed."
    exit 1
fi
