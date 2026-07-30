#!/usr/bin/env bash
#
# setup-local-scratch-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Prepares instance-store (local NVMe) disks as fast scratch space: it finds the
# ephemeral NVMe device(s), creates a filesystem only if one is not already
# present, mounts it, and sets permissions. Instance-store volumes are blank on
# every fresh instance, so a compute node can use this for high-throughput
# temporary I/O that does not need to persist.
#
# This example demonstrates *idempotent storage setup*: it never reformats a
# device that already has a filesystem, and it is a no-op if the mount point is
# already mounted — so it is safe on EVERY_BOOT.
#
# NOTE: This script targets a SINGLE instance-store device (the first it finds).
# Nodes with multiple NVMe instance-store volumes would typically stripe them
# with LVM/mdadm; that is intentionally out of scope for this example.
#
# Prerequisites: nvme-cli (usually present); mkfs for the chosen filesystem.
# IAM: none.
# Suggested execution policy: EVERY_BOOT (re-mount ephemeral storage on reboot).
# Suggested onError: CONTINUE (nodes without local NVMe should still start).
#
# Usage:
#   setup-local-scratch-v1.0.0.sh [--mount-point PATH] [--fstype FS] [--mode MODE]
#
# Flags:
#   --mount-point PATH  Where to mount scratch (default: /scratch).
#   --fstype FS         Filesystem to create if none exists (default: ext4).
#   --mode MODE         chmod mode for the mount point (default: 1777).
#   -h, --help          Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[setup-local-scratch] $*"; }
warn() { echo "[setup-local-scratch] WARNING: $*" >&2; }
die()  { echo "[setup-local-scratch] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,34p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

MOUNT_POINT="/scratch"
FSTYPE="ext4"
MODE="1777"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mount-point) MOUNT_POINT="${2:-}"; shift 2 ;;
        --fstype)      FSTYPE="${2:-}"; shift 2 ;;
        --mode)        MODE="${2:-}"; shift 2 ;;
        -h|--help)     usage 0 ;;
        *)             warn "Unknown argument: $1"; usage 1 ;;
    esac
done

[[ "$(id -u)" -eq 0 ]] || die "This script must run as root."

# --- Find an instance-store NVMe device --------------------------------------
# Amazon EC2 exposes instance-store volumes as NVMe devices whose controller
# model is "Amazon EC2 NVMe Instance Storage". EBS volumes report a different
# model, so we can distinguish them without risking an EBS root volume.
find_instance_store_device() {
    command -v nvme >/dev/null 2>&1 || { warn "nvme-cli not found."; return 1; }
    local dev
    for dev in /dev/nvme*n1; do
        [[ -e "${dev}" ]] || continue
        if nvme id-ctrl "${dev}" 2>/dev/null | grep -qi "Instance Storage"; then
            echo "${dev}"
            return 0
        fi
    done
    return 1
}

DEVICE="$(find_instance_store_device || true)"
if [[ -z "${DEVICE}" ]]; then
    warn "No instance-store NVMe device found on this instance type. Nothing to do."
    exit 0
fi
log "Found instance-store device: ${DEVICE}"

# --- Create a filesystem only if the device has none (idempotent) ------------
existing_fs="$(blkid -o value -s TYPE "${DEVICE}" 2>/dev/null || true)"
if [[ -z "${existing_fs}" ]]; then
    log "No filesystem on ${DEVICE}; creating ${FSTYPE}"
    "mkfs.${FSTYPE}" -q "${DEVICE}" || die "mkfs.${FSTYPE} failed on ${DEVICE}"
else
    log "Device ${DEVICE} already has a ${existing_fs} filesystem; not reformatting."
fi

# --- Mount (idempotent) ------------------------------------------------------
mkdir -p "${MOUNT_POINT}"
if mountpoint -q "${MOUNT_POINT}"; then
    log "${MOUNT_POINT} is already mounted; leaving it in place."
else
    log "Mounting ${DEVICE} at ${MOUNT_POINT}"
    mount "${DEVICE}" "${MOUNT_POINT}" || die "Failed to mount ${DEVICE} at ${MOUNT_POINT}"
fi

chmod "${MODE}" "${MOUNT_POINT}"
log "Local scratch ready at ${MOUNT_POINT} (mode ${MODE})."
