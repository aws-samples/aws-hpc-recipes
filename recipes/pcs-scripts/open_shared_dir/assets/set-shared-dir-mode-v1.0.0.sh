#!/usr/bin/env bash
#
# set-shared-dir-mode-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Opens permissions on an already-mounted shared directory so that every user on
# the node can read and write to it. A common use is a shared FSx for Lustre or
# EFS scratch directory (for example /fsx) that is mounted root-owned by default:
# on a single-user "try it out" cluster you often want any user to be able to
# write there without sudo.
#
# This runs AFTER the mount that provides the directory (for example the
# AWS-maintained mount-fsx-lustre.sh action). It is intentionally a NO-OP when the
# path is not yet a mount point, so an out-of-order run during bootstrap cannot
# chmod a local directory by mistake and cannot fail the node.
#
# By default it applies mode 1777 (world-writable with the sticky bit, like /tmp),
# so users cannot delete each other's files. Pass --mode 0777 to match a plain
# `chmod 777` with no sticky bit.
#
# Prerequisites: coreutils (chmod), util-linux (mountpoint) — present on supported OSes.
# IAM: none.
# Suggested execution policy: EVERY_BOOT (re-apply after the mount on every reboot).
# Suggested onError: CONTINUE (a node should still start if the share is absent).
#
# Usage:
#   set-shared-dir-mode-v1.0.0.sh --path PATH [--mode MODE]
#
# Flags:
#   --path PATH  Absolute path of the mounted shared directory (required), e.g. /fsx.
#   --mode MODE  chmod mode to apply (default: 1777).
#   -h, --help   Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[set-shared-dir-mode] $*"; }
warn() { echo "[set-shared-dir-mode] WARNING: $*" >&2; }
die()  { echo "[set-shared-dir-mode] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,29p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

PATH_ARG=""
MODE="1777"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path) PATH_ARG="${2:-}"; shift 2 ;;
        --mode) MODE="${2:-}"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) warn "Unknown argument: $1"; usage 1 ;;
    esac
done

[[ "$(id -u)" -eq 0 ]] || die "This script must run as root."
[[ -n "${PATH_ARG}" ]] || { warn "Missing required --path"; usage 1; }
[[ "${PATH_ARG}" == /* ]] || die "--path must be an absolute path, got: ${PATH_ARG}"

# Best-effort ordering guard: only touch a real mount point. If the mount action
# that provides this directory has not run yet (or was skipped), do nothing and
# exit 0 rather than chmod'ing a local directory or failing the node.
if [[ ! -d "${PATH_ARG}" ]] || ! mountpoint -q "${PATH_ARG}"; then
    warn "${PATH_ARG} is not a mount point; the shared filesystem is not mounted here. Nothing to do."
    exit 0
fi

log "Setting mode ${MODE} on shared directory ${PATH_ARG}"
chmod "${MODE}" "${PATH_ARG}" || die "Failed to chmod ${MODE} ${PATH_ARG}"
log "Shared directory ${PATH_ARG} is now mode ${MODE}."
