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
# /etc/motd is only rendered by pam_motd on a true SSH login. Sessions opened
# via SSM Session Manager or `sudo -i` do not run that PAM stack, so the banner
# would be invisible there. To cover those paths the script also installs a
# small /etc/profile.d dispatcher that prints the banner in interactive login
# shells while staying quiet on SSH (where pam_motd already printed it).
#
# Context variables used (exported by the PCS agent):
#   PCS_CLUSTER_NAME, PCS_CLUSTER_ID, PCS_COMPUTE_NODE_GROUP_NAME, PCS_NODE_ID
#
# Prerequisites: none (coreutils only).
# IAM: none.
# Suggested execution policy: EVERY_BOOT (idempotent — rewrites its files).
# Suggested onError: CONTINUE (a cosmetic banner should never fail a node).
#
# Usage:
#   set-cluster-motd-v1.0.0.sh [--message TEXT] [--motd-file PATH]
#                              [--profile-dropin PATH | --no-profile-dropin]
#
# Flags:
#   --message TEXT       Optional welcome line shown at the top of the banner.
#   --motd-file PATH     File to write (default: /etc/motd).
#   --profile-dropin PATH  Login-shell dispatcher to install
#                          (default: /etc/profile.d/zz-pcs-motd.sh).
#   --no-profile-dropin  Do not install the login-shell dispatcher.
#   -h, --help           Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[set-cluster-motd] $*"; }
warn() { echo "[set-cluster-motd] WARNING: $*" >&2; }
die()  { echo "[set-cluster-motd] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,35p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

MESSAGE=""
MOTD_FILE="/etc/motd"
PROFILE_DROPIN="/etc/profile.d/zz-pcs-motd.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --message)         MESSAGE="${2:-}"; shift 2 ;;
        --motd-file)       MOTD_FILE="${2:-}"; shift 2 ;;
        --profile-dropin)  PROFILE_DROPIN="${2:-}"; shift 2 ;;
        --no-profile-dropin) PROFILE_DROPIN=""; shift ;;
        -h|--help)         usage 0 ;;
        *)                 warn "Unknown argument: $1"; usage 1 ;;
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

log "MOTD written to ${MOTD_FILE}."

# --- Install a login-shell dispatcher (covers SSM and sudo -i) ---------------
# pam_motd renders ${MOTD_FILE} only on a true SSH login. SSM Session Manager
# and `sudo -i` open interactive login shells that skip that PAM stack, so the
# banner would be invisible there. A /etc/profile.d drop-in is sourced by any
# interactive login shell and fills that gap. It re-reads ${MOTD_FILE} (one
# source of truth) and stays quiet on SSH, where pam_motd already printed it.
if [[ -n "${PROFILE_DROPIN}" ]]; then
    dropin_dir="$(dirname "${PROFILE_DROPIN}")"
    if [[ -d "${dropin_dir}" ]]; then
        tmp_dropin="$(mktemp)"
        trap 'rm -f "${tmp_dropin}"' EXIT
        cat > "${tmp_dropin}" <<EOF
# Managed by set-cluster-motd (PCS node lifecycle action). Do not edit.
# Print the cluster MOTD for interactive login shells that pam_motd misses
# (SSM Session Manager, sudo -i). SSH already prints it, so stay quiet there
# to avoid a double banner.
if [ -n "\${PS1:-}" ] && [ -z "\${SSH_CONNECTION:-}" ] && [ -r "${MOTD_FILE}" ]; then
    cat "${MOTD_FILE}"
fi
EOF
        mv "${tmp_dropin}" "${PROFILE_DROPIN}"
        trap - EXIT
        chmod 0644 "${PROFILE_DROPIN}"
        log "Login-shell dispatcher installed at ${PROFILE_DROPIN}."
    else
        warn "Profile drop-in directory ${dropin_dir} not found; skipping dispatcher."
    fi
fi
