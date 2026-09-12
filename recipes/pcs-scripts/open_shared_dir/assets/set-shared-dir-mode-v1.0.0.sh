#!/usr/bin/env bash
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
#DESCRIPTION: Sets the permissions mode on an already-mounted shared directory so every user on the node can write to it
#VERSION: 1.0.0
#OS: AL2, AL2023, Ubuntu22, Ubuntu24, Rhel9, Rhel8, Rocky9, Rocky8
#PACKAGES: coreutils (chmod), util-linux (mountpoint) — present on all supported OSes
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
# AWS-maintained mount-fsx-lustre.sh action). Because the preceding mount may not
# have finished when this script fires at node boot, it waits up to --wait-seconds
# for the path to become a mount point. If it never does, the script warns and
# exits 0 rather than chmod'ing a local directory or failing the node.
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
# Usage: set-shared-dir-mode-v1.0.0.sh --path PATH [--mode MODE] [--wait-seconds N]

set -o errexit -o pipefail -o nounset

# The PCS agent captures stdout and stderr to the per-script log at
# /var/log/amazon/pcs/lifecycle/actions/<stage>/<script>.log. The timestamp lets
# these lines be interleaved with the agent's own executor.log when working out
# what happened, and in what order, during node bootstrap.
_ts()  { date +'%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(_ts)] [set-shared-dir-mode] INFO: $*"; }
warn() { echo "[$(_ts)] [set-shared-dir-mode] WARNING: $*" >&2; }
die()  { echo "[$(_ts)] [set-shared-dir-mode] ERROR: $*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
Usage: set-shared-dir-mode-v1.0.0.sh --path PATH [--mode MODE] [--wait-seconds N]

Set the permissions mode on an already-mounted shared directory.

Required flags:
  --path PATH        Absolute path of the mounted shared directory, e.g. /fsx

Optional flags:
  --mode MODE        chmod mode to apply (default: 1777)
  --wait-seconds N   How long to wait for PATH to become a mount point before
                     giving up and exiting 0 (default: 30, 0 to skip waiting)
  -h, --help         Show this help and exit
USAGE
    exit "${1:-0}"
}

PATH_ARG=""
MODE="1777"
WAIT_SECONDS="30"

# How often to re-check for the mount point while waiting.
POLL_INTERVAL=2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path) PATH_ARG="${2:-}"; shift 2 ;;
        --mode) MODE="${2:-}"; shift 2 ;;
        --wait-seconds) WAIT_SECONDS="${2:-}"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) warn "Unknown argument: $1"; usage 1 ;;
    esac
done

[[ "$(id -u)" -eq 0 ]] || die "This script must run as root."
[[ -n "${PATH_ARG}" ]] || { warn "Missing required --path"; usage 1; }
[[ "${PATH_ARG}" == /* ]] || die "--path must be an absolute path, got: ${PATH_ARG}"
[[ "${WAIT_SECONDS}" =~ ^[0-9]+$ ]] || die "--wait-seconds must be a non-negative integer, got: ${WAIT_SECONDS}"

# Ordering guard: only ever touch a real mount point, so an out-of-order run
# during bootstrap cannot chmod a local directory by mistake.
#
# A missing mount point can mean two different things, and they need different
# handling. It can be a configuration miss (no mount action was ever
# configured), or it can be a timing miss — at node boot the preceding mount
# action may simply not have finished yet. Waiting a bounded time tells the two
# apart. If the path never becomes a mount point, warn and exit 0 rather than
# failing the node.
is_mounted() {
    [[ -d "${PATH_ARG}" ]] && mountpoint -q "${PATH_ARG}"
}

if ! is_mounted; then
    if (( WAIT_SECONDS > 0 )); then
        log "${PATH_ARG} is not a mount point yet; waiting up to ${WAIT_SECONDS}s for the mount to appear."
        deadline=$(( SECONDS + WAIT_SECONDS ))
        while (( SECONDS < deadline )); do
            sleep "${POLL_INTERVAL}"
            if is_mounted; then
                log "${PATH_ARG} is now a mount point."
                break
            fi
        done
    fi
    if ! is_mounted; then
        warn "${PATH_ARG} is not a mount point; the shared filesystem is not mounted here. Nothing to do."
        exit 0
    fi
fi

log "Setting mode ${MODE} on shared directory ${PATH_ARG}"
chmod "${MODE}" "${PATH_ARG}" || die "Failed to chmod ${MODE} ${PATH_ARG}"
log "Shared directory ${PATH_ARG} is now mode ${MODE}."
