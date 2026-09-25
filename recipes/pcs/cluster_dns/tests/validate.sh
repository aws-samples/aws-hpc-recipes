#!/bin/bash
# validate.sh — Validation script for pcs/cluster_dns recipe
#
# Runs automated checks suitable for CI: shell script syntax and linting, the
# script checksum, example JSON validity, partition safety of the script/JSON
# assets, and cfn-lint on the CloudFormation template. Repository-wide checks
# (structure, metadata schema, template partition safety) also run in the
# top-level `make validate`.
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
# Check 4: Partition safety of script/JSON assets
###############################################################################
echo "Check 4: Partition safety (scripts and JSON)"
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
# Check 5: Script checksums present and current
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
# Check 5b: The digest pinned in the example JSON matches the script it names
###############################################################################
# This is the copy that matters at runtime: the PCS agent verifies it before running
# the script as root, and it is the copy operators paste into their node-group config.
# `make checksums` maintains both, but a hand-edit can move one and not the other.
echo "Check 5b: Example JSON checksum pin"
EXAMPLE_JSON="${ASSETS_DIR}/example-node-lifecycle-actions.json"
if [[ -f "${EXAMPLE_JSON}" ]]; then
    while IFS=$'\t' read -r pinned_name pinned_sum; do
        [[ -n "${pinned_name}" ]] || continue
        target="${ASSETS_DIR}/${pinned_name}"
        if [[ ! -f "${target}" ]]; then
            fail "${pinned_name} — pinned in example JSON but not present in assets/"
            continue
        fi
        actual="$(${HASH_CMD} "${target}" | awk '{print $1}')"
        if [[ "${pinned_sum}" == "${actual}" ]]; then
            pass "${pinned_name} — example JSON checksum matches"
        else
            fail "${pinned_name} — example JSON checksum stale (run 'make checksums')"
        fi
    done < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for acts in d.get("stages", {}).values():
    for a in acts:
        src = a.get("scriptSource")
        if src and "checksum" in src:
            print(src["scriptLocation"].rsplit("/", 1)[-1], src["checksum"], sep="\t")
' "${EXAMPLE_JSON}")
else
    fail "example-node-lifecycle-actions.json — missing"
fi

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
# Check 7: cfn-lint on the template
###############################################################################
echo "Check 7: cfn-lint"
TEMPLATE="${ASSETS_DIR}/cluster-dns.yaml"
if command -v cfn-lint >/dev/null 2>&1; then
    if cfn-lint "${TEMPLATE}" >/dev/null 2>&1; then
        pass "cluster-dns.yaml — cfn-lint OK"
    else
        fail "cluster-dns.yaml — cfn-lint findings (run 'cfn-lint ${TEMPLATE}')"
    fi
else
    echo "  ⚠ cfn-lint not installed — skipping"
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
