#!/usr/bin/env bash
#
# prepare-hpc-node-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Applies common HPC node tuning: raises resource limits (open files, processes,
# and locked memory), optionally disables Transparent Huge Pages (THP), and
# applies a couple of network sysctls that benefit tightly-coupled workloads.
#
# This example demonstrates writing system configuration *idempotently* so it is
# safe to run on EVERY_BOOT: it writes drop-in files under /etc/security/limits.d
# and /etc/sysctl.d (overwriting them each run rather than appending), and it
# reasserts the THP state on every boot.
#
# Prerequisites: none (coreutils + sysctl, present on all supported OSes).
# IAM: none.
# Suggested execution policy: EVERY_BOOT (limits.d/sysctl.d must be reasserted).
# Suggested onError: TERMINATE (a node that is not tuned may fail jobs).
#
# Usage:
#   prepare-hpc-node-v1.0.0.sh [--nofile N] [--nproc N] [--memlock VALUE]
#                              [--disable-thp] [--somaxconn N]
#
# Flags:
#   --nofile N        Max open files (soft and hard). Default: 131072.
#   --nproc N         Max user processes (soft and hard). Default: 65536.
#   --memlock VALUE   Max locked-in-memory (KB or 'unlimited'). Default: unlimited.
#   --disable-thp     Disable Transparent Huge Pages for this boot.
#   --somaxconn N     net.core.somaxconn sysctl. Default: 65535.
#   -h, --help        Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[prepare-hpc-node] $*"; }
warn() { echo "[prepare-hpc-node] WARNING: $*" >&2; }
die()  { echo "[prepare-hpc-node] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,32p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

NOFILE="131072"
NPROC="65536"
MEMLOCK="unlimited"
DISABLE_THP="false"
SOMAXCONN="65535"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --nofile)      NOFILE="${2:-}"; shift 2 ;;
        --nproc)       NPROC="${2:-}"; shift 2 ;;
        --memlock)     MEMLOCK="${2:-}"; shift 2 ;;
        --somaxconn)   SOMAXCONN="${2:-}"; shift 2 ;;
        --disable-thp) DISABLE_THP="true"; shift ;;
        -h|--help)     usage 0 ;;
        *)             warn "Unknown argument: $1"; usage 1 ;;
    esac
done

[[ "$(id -u)" -eq 0 ]] || die "This script must run as root."

# --- Resource limits ---------------------------------------------------------
# A drop-in under limits.d is idempotent: we rewrite the whole file each run.
LIMITS_FILE="/etc/security/limits.d/99-hpc.conf"
log "Writing resource limits to ${LIMITS_FILE}"
cat > "${LIMITS_FILE}" <<EOF
# Managed by prepare-hpc-node (AWS HPC Recipes). Do not edit by hand.
*    soft    nofile    ${NOFILE}
*    hard    nofile    ${NOFILE}
*    soft    nproc     ${NPROC}
*    hard    nproc     ${NPROC}
*    soft    memlock   ${MEMLOCK}
*    hard    memlock   ${MEMLOCK}
EOF
chmod 0644 "${LIMITS_FILE}"

# --- Kernel sysctls ----------------------------------------------------------
SYSCTL_FILE="/etc/sysctl.d/99-hpc.conf"
log "Writing sysctls to ${SYSCTL_FILE}"
cat > "${SYSCTL_FILE}" <<EOF
# Managed by prepare-hpc-node (AWS HPC Recipes). Do not edit by hand.
net.core.somaxconn = ${SOMAXCONN}
EOF
chmod 0644 "${SYSCTL_FILE}"

if command -v sysctl >/dev/null 2>&1; then
    log "Applying sysctl settings"
    sysctl --system >/dev/null
else
    warn "sysctl not found; settings will apply on next boot."
fi

# --- Transparent Huge Pages --------------------------------------------------
# THP state is not persistent, so reasserting it on every boot is correct.
if [[ "${DISABLE_THP}" == "true" ]]; then
    thp="/sys/kernel/mm/transparent_hugepage/enabled"
    if [[ -w "${thp}" ]]; then
        log "Disabling Transparent Huge Pages"
        echo never > "${thp}"
    else
        warn "THP control file not writable (${thp}); skipping."
    fi
fi

log "HPC node tuning applied successfully."
