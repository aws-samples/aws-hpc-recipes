#!/bin/bash
# validate.sh — Validation script for pcs/nice_dcv recipe
#
# Runs automated checks for CI pipeline integration.
# Exit codes: 0 = all checks pass, 1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECIPE_DIR="$(dirname "${SCRIPT_DIR}")"
ASSETS_DIR="${RECIPE_DIR}/assets"
ERRORS=0

###############################################################################
# Helper functions
###############################################################################
pass() {
    echo "  ✓ $1"
}

fail() {
    echo "  ✗ $1"
    ERRORS=$((ERRORS + 1))
}

###############################################################################
# Check 1: Shell script syntax
###############################################################################
echo "Check 1: Shell script syntax (bash -n)"

for script in "${ASSETS_DIR}/install-relion.sh" "${SCRIPT_DIR}/validate.sh"; do
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

if command -v shellcheck &>/dev/null; then
    for script in "${ASSETS_DIR}/install-relion.sh" "${SCRIPT_DIR}/validate.sh"; do
        if shellcheck "${script}" 2>/dev/null; then
            pass "$(basename "${script}") — ShellCheck OK"
        else
            fail "$(basename "${script}") — ShellCheck warnings/errors"
        fi
    done
else
    echo "  ⚠ ShellCheck not installed — skipping"
fi

###############################################################################
# Check 3: YAML validity
###############################################################################
echo "Check 3: YAML validity"

if command -v yamllint &>/dev/null; then
    if yamllint "${RECIPE_DIR}/metadata.yml" 2>/dev/null; then
        pass "metadata.yml — valid YAML"
    else
        fail "metadata.yml — YAML lint errors"
    fi
else
    echo "  ⚠ yamllint not installed — skipping"
fi

###############################################################################
# Check 4: Metadata schema (required fields)
###############################################################################
echo "Check 4: Metadata schema"

METADATA="${RECIPE_DIR}/metadata.yml"
for field in "name:" "version:" "description:" "tags:" "type:"; do
    if grep -q "${field}" "${METADATA}"; then
        pass "metadata.yml contains ${field}"
    else
        fail "metadata.yml missing ${field}"
    fi
done

###############################################################################
# Check 5: Partition safety
###############################################################################
echo "Check 5: Partition safety (no hardcoded arn:aws: or amazonaws.com)"

for file in "${ASSETS_DIR}/install-relion.sh" "${ASSETS_DIR}/dcv-linux-node.yaml"; do
    filename="$(basename "${file}")"

    # Check for hardcoded arn:aws: (excluding comments and the partition-safe pattern)
    if grep -n "arn:aws:" "${file}" | grep -v "AWS::Partition" | grep -v "^#" | grep -v "# " > /dev/null 2>&1; then
        fail "${filename} — contains hardcoded arn:aws:"
    else
        pass "${filename} — no hardcoded arn:aws:"
    fi

    # Check for hardcoded amazonaws.com (excluding comments, URLSuffix pattern, S3 URLs, and service principals)
    if grep -n "amazonaws.com" "${file}" | grep -v "AWS::URLSuffix" | grep -v "^#" | grep -v "# " | grep -v "s3.us-east-1.amazonaws.com" | grep -v "Service:" > /dev/null 2>&1; then
        fail "${filename} — contains hardcoded amazonaws.com"
    else
        pass "${filename} — no hardcoded amazonaws.com"
    fi
done

###############################################################################
# Check 6: README structure
###############################################################################
echo "Check 6: README structure"

README="${RECIPE_DIR}/README.md"
EXPECTED_HEADINGS=(
    "## Introduction"
    "## Overview"
    "## Prerequisites"
    "## Step 1"
    "## Step 2"
    "## Step 3"
    "## Step 4"
    "## Step 5"
    "## Operational Guidance"
    "## Production Considerations"
    "## Cost Estimation"
    "## Troubleshooting"
    "## Cleanup"
)

for heading in "${EXPECTED_HEADINGS[@]}"; do
    if grep -q "${heading}" "${README}"; then
        pass "README.md contains '${heading}'"
    else
        fail "README.md missing '${heading}'"
    fi
done

###############################################################################
# Check 7: CloudFormation template validation (requires AWS credentials)
###############################################################################
echo "Check 7: CloudFormation template validation"

if aws sts get-caller-identity &>/dev/null 2>&1; then
    if aws cloudformation validate-template \
        --template-body "file://${ASSETS_DIR}/dcv-linux-node.yaml" \
        --output text > /dev/null 2>&1; then
        pass "dcv-linux-node.yaml — CloudFormation validation passed"
    else
        fail "dcv-linux-node.yaml — CloudFormation validation failed"
    fi
else
    echo "  ⚠ No AWS credentials — skipping CloudFormation validation"
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
