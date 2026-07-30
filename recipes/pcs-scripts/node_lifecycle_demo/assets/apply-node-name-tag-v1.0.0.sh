#!/usr/bin/env bash
#
# apply-node-name-tag-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Tags the EC2 instance with Name=<PCS_NODE_ID> (by default) so that instances
# are easy to correlate with PCS nodes in the EC2 console, Cost Explorer, and
# your own tooling.
#
# It shows how to combine three things:
#   1. Lifecycle CONTEXT — PCS_NODE_ID, injected by the PCS agent, is the tag value.
#   2. Instance metadata — the EC2 instance-id (needed for the API call) and the
#      Region come from IMDSv2.
#   3. Least-privilege IAM — the call needs ec2:CreateTags on the instance.
#
# The action is BEST-EFFORT: if the AWS CLI is not installed, or the CreateTags
# call is denied or fails, the script logs a warning and exits 0. Pair it with
# onError: CONTINUE so a missing tag never terminates a node. If you want tagging
# to be mandatory, change onError to TERMINATE and remove the best-effort exits.
#
# Prerequisites: awscli (and its Python runtime) on the AMI for tagging to occur.
# IAM: ec2:CreateTags on the node's instance (see the recipe README for a policy).
# Suggested execution policy: FIRST_BOOT_ONLY (the Name tag does not change).
# Suggested onError: CONTINUE (best-effort).
#
# Usage:
#   apply-node-name-tag-v1.0.0.sh [--tag-key KEY] [--tag-value VALUE] [--region REGION]
#
# Flags:
#   --tag-key KEY      Tag key to set (default: Name).
#   --tag-value VALUE  Tag value (default: the PCS_NODE_ID context variable).
#   --region REGION    AWS Region (default: discovered from IMDSv2).
#   -h, --help         Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[apply-node-name-tag] $*"; }
warn() { echo "[apply-node-name-tag] WARNING: $*" >&2; }
die()  { echo "[apply-node-name-tag] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,32p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

TAG_KEY="Name"
TAG_VALUE="${PCS_NODE_ID:-}"
REGION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag-key)   TAG_KEY="${2:-}"; shift 2 ;;
        --tag-value) TAG_VALUE="${2:-}"; shift 2 ;;
        --region)    REGION="${2:-}"; shift 2 ;;
        -h|--help)   usage 0 ;;
        *)           warn "Unknown argument: $1"; usage 1 ;;
    esac
done

# --- IMDSv2 helper -----------------------------------------------------------
# Short timeouts so the script fails fast (and, being best-effort, skips) when
# IMDS is unreachable or disabled, rather than stalling node bootstrap.
imds_get() {
    local path="$1" token
    token="$(curl -fsS --connect-timeout 1 --max-time 2 \
        -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)"
    [[ -n "${token}" ]] || { echo ""; return 0; }
    curl -fsS --connect-timeout 1 --max-time 2 \
        -H "X-aws-ec2-metadata-token: ${token}" \
        "http://169.254.169.254/latest/meta-data/${path}" 2>/dev/null || echo ""
}

# --- Validate inputs (best-effort: warn and exit 0 on anything missing) ------
if [[ -z "${TAG_VALUE}" ]]; then
    warn "No tag value: PCS_NODE_ID is not set and --tag-value was not provided. Skipping."
    exit 0
fi

if ! command -v aws >/dev/null 2>&1; then
    warn "AWS CLI not found on this AMI. Cannot tag the instance. Skipping."
    warn "Install 'awscli' in your AMI to enable instance tagging."
    exit 0
fi

INSTANCE_ID="$(imds_get "instance-id")"
if [[ -z "${INSTANCE_ID}" ]]; then
    warn "Could not read instance-id from IMDSv2. Skipping."
    exit 0
fi

if [[ -z "${REGION}" ]]; then
    # e.g. us-west-2a -> us-west-2. Prefer the dedicated placement/region path,
    # falling back to trimming the AZ suffix for older metadata layouts.
    REGION="$(imds_get "placement/region")"
    if [[ -z "${REGION}" ]]; then
        az="$(imds_get "placement/availability-zone")"
        REGION="${az%[a-z]}"
    fi
fi
if [[ -z "${REGION}" ]]; then
    warn "Could not determine the AWS Region. Skipping."
    exit 0
fi

# --- Apply the tag (best-effort) ---------------------------------------------
log "Tagging instance ${INSTANCE_ID} in ${REGION} with ${TAG_KEY}=${TAG_VALUE}"

if aws ec2 create-tags \
    --region "${REGION}" \
    --resources "${INSTANCE_ID}" \
    --tags "Key=${TAG_KEY},Value=${TAG_VALUE}" 2>/tmp/create-tags.err; then
    log "Tag applied successfully."
else
    warn "create-tags failed (this is best-effort; the node continues):"
    warn "$(cat /tmp/create-tags.err 2>/dev/null || true)"
    warn "Confirm the node instance role allows ec2:CreateTags on this instance."
    exit 0
fi
