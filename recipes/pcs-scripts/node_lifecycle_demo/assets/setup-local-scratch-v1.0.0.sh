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
# NOTE: Some AMIs prepare the instance-store volume for you. For example, the AWS
# Deep Learning AMI (DLAMI) mounts it at /opt/dlami/nvme via LVM. When the device
# is already claimed — mounted elsewhere, or part of an LVM/RAID set — this script
# leaves it untouched and exits 0 rather than reformatting storage already in use.
#
# Prerequisites: util-linux (lsblk, blkid, findmnt) and mkfs for the chosen
#   filesystem — all present on supported OSes. nvme-cli is used as a fallback if
#   present, but is NOT required.
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
    sed -n '3,39p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
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
# Amazon EC2 exposes instance-store volumes as NVMe devices whose model is
# "Amazon EC2 NVMe Instance Storage". EBS volumes report a different model, so we
# can distinguish them without risking an EBS root volume. We read the model with
# lsblk (util-linux, always present) so nvme-cli is not required; if lsblk cannot
# report a model and nvme-cli happens to be installed, we fall back to it.
find_instance_store_device() {
    local dev model
    for dev in /dev/nvme*n1; do
        [[ -e "${dev}" ]] || continue
        model="$(lsblk -dno MODEL "${dev}" 2>/dev/null || true)"
        if printf '%s' "${model}" | grep -qi "Instance Storage"; then
            echo "${dev}"
            return 0
        fi
        if command -v nvme >/dev/null 2>&1 && \
           nvme id-ctrl "${dev}" 2>/dev/null | grep -qi "Instance Storage"; then
            echo "${dev}"
            return 0
        fi
    done
    return 1
}

# Returns 0 if the device is already claimed by the system: mounted anywhere, or
# consumed by LVM/RAID/LUKS. LVM/RAID members surface as child devices in lsblk;
# an unused-but-initialized member surfaces as a container filesystem signature.
# A device carrying only a plain filesystem we manage has no children and is not
# treated as claimed, so the idempotent remount path below still applies.
device_is_claimed() {
    local dev="$1" base children fstype
    findmnt -nro SOURCE "${dev}" >/dev/null 2>&1 && return 0
    base="$(basename "${dev}")"
    children="$(lsblk -nro NAME "${dev}" 2>/dev/null | grep -vx "${base}" || true)"
    [[ -n "${children}" ]] && return 0
    fstype="$(blkid -o value -s TYPE "${dev}" 2>/dev/null || true)"
    case "${fstype}" in
        LVM2_member|linux_raid_member|crypto_LUKS) return 0 ;;
    esac
    return 1
}

DEVICE="$(find_instance_store_device || true)"
if [[ -z "${DEVICE}" ]]; then
    warn "No instance-store NVMe device found on this instance type. Nothing to do."
    exit 0
fi
log "Found instance-store device: ${DEVICE}"

# If the AMI already prepared the device (mounted elsewhere or part of an LVM/RAID
# set — for example the DLAMI's /opt/dlami/nvme), leave it untouched. Formatting or
# mounting it here would clobber storage the system is already using.
if device_is_claimed "${DEVICE}"; then
    existing_mount="$(findmnt -nro TARGET "${DEVICE}" 2>/dev/null || true)"
    log "Device ${DEVICE} is already prepared by this AMI${existing_mount:+ (mounted at ${existing_mount})}; nothing to do."
    exit 0
fi

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
