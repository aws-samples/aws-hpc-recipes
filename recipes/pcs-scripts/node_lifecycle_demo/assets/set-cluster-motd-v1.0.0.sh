#!/usr/bin/env bash
#
# set-cluster-motd-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Writes a message-of-the-day banner that greets users with details about the
# cluster and node they have landed on. This is the simplest example in the
# node_lifecycle_demo recipe: it demonstrates reading the *lifecycle context*
# that AWS PCS injects into every lifecycle action script, combined with
# instance metadata retrieved from IMDSv2.
#
# Context variables used (exported by the PCS agent):
#   PCS_CLUSTER_NAME, PCS_CLUSTER_ID, PCS_COMPUTE_NODE_GROUP_NAME, PCS_NODE_ID
#
# Prerequisites: none (coreutils only).
# IAM: none.
# Suggested execution policy: EVERY_BOOT (idempotent — rewrites /etc/motd).
# Suggested onError: CONTINUE (a cosmetic banner should never fail a node).
#
# Usage:
#   set-cluster-motd-v1.0.0.sh [--message TEXT] [--motd-file PATH]
#
# Flags:
#   --message TEXT     Optional welcome line shown at the top of the banner.
#   --motd-file PATH   File to write (default: /etc/motd).
#   -h, --help         Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[set-cluster-motd] $*"; }
warn() { echo "[set-cluster-motd] WARNING: $*" >&2; }
die()  { echo "[set-cluster-motd] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,30p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

MESSAGE=""
MOTD_FILE="/etc/motd"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --message)   MESSAGE="${2:-}"; shift 2 ;;
        --motd-file) MOTD_FILE="${2:-}"; shift 2 ;;
        -h|--help)   usage 0 ;;
        *)           warn "Unknown argument: $1"; usage 1 ;;
    esac
done

# --- Query IMDSv2 for instance facts (best-effort) --------------------------
# IMDSv2 is token-based. If the token cannot be fetched (IMDS disabled or
# unreachable), fall back to "unknown" rather than failing the banner.
# Short timeouts so the banner fails fast when IMDS is unreachable or disabled,
# rather than stalling node bootstrap.
imds_get() {
    local path="$1" token
    token="$(curl -fsS --connect-timeout 1 --max-time 2 \
        -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)"
    [[ -n "${token}" ]] || { echo "unknown"; return 0; }
    curl -fsS --connect-timeout 1 --max-time 2 \
        -H "X-aws-ec2-metadata-token: ${token}" \
        "http://169.254.169.254/latest/meta-data/${path}" 2>/dev/null || echo "unknown"
}

INSTANCE_ID="$(imds_get "instance-id")"
INSTANCE_TYPE="$(imds_get "instance-type")"
AVAILABILITY_ZONE="$(imds_get "placement/availability-zone")"

# Lifecycle context is provided by the PCS agent. Default to "unknown" so the
# script also runs cleanly when tested outside of a lifecycle action.
cluster_name="${PCS_CLUSTER_NAME:-unknown}"
cluster_id="${PCS_CLUSTER_ID:-unknown}"
node_group="${PCS_COMPUTE_NODE_GROUP_NAME:-unknown}"
node_id="${PCS_NODE_ID:-unknown}"

log "Writing MOTD to ${MOTD_FILE} for node ${node_id} in cluster ${cluster_name}"

# --- Compose the banner ------------------------------------------------------
# Write atomically to a temp file, then move into place so a partial write is
# never visible. This keeps the action idempotent and safe on every boot.
tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

{
    echo "==============================================================="
    if [[ -n "${MESSAGE}" ]]; then
        echo "  ${MESSAGE}"
        echo "---------------------------------------------------------------"
    fi
    echo "  AWS Parallel Computing Service"
    echo ""
    printf "  %-22s %s\n" "Cluster:"          "${cluster_name} (${cluster_id})"
    printf "  %-22s %s\n" "Compute node group:" "${node_group}"
    printf "  %-22s %s\n" "PCS node ID:"       "${node_id}"
    printf "  %-22s %s\n" "EC2 instance:"      "${INSTANCE_ID} (${INSTANCE_TYPE})"
    printf "  %-22s %s\n" "Availability Zone:" "${AVAILABILITY_ZONE}"
    echo "==============================================================="
} > "${tmp_file}"

mv "${tmp_file}" "${MOTD_FILE}"
trap - EXIT
chmod 0644 "${MOTD_FILE}"

log "MOTD written successfully."
