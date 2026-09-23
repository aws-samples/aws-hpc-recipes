#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# seed-demo-users-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Creates demo Linux users (alice, bob) at fixed POSIX uid/gid. Designed for use
# with the rest_api_cognito recipe: the uid/gid values must match the Cognito
# custom attributes so that identity propagation from the JWT to the Slurm
# scheduler is provably consistent.
#
# The account's home directory lives under a shared filesystem (EFS) that the
# configure-efs-homes AWS-maintained NLA mounts at --home-base (default /home)
# BEFORE this script runs. configure-efs-homes provides the MOUNT, not the
# per-user directories, so this script creates <home-base>/<user> and chowns it
# to the user. That directory must exist and be writable or batch jobs whose
# working directory is the home fail (Slurm RaisedSignal:53).
#
# Order this action AFTER configure-efs-homes in the NodeBootstrapped stage.
#
# Prerequisites: none (coreutils only). The --home-base path must already be a
#   writable (shared) mount when this runs.
# IAM: none.
# Suggested execution policy: FIRST_BOOT_ONLY (idempotent — re-run is safe).
# Suggested onError: CONTINUE
#
# Usage:
#   seed-demo-users-v1.0.0.sh [--alice-uid UID] [--alice-gid GID]
#                              [--bob-uid UID] [--bob-gid GID]
#                              [--home-base PATH] [-h|--help]

set -o errexit -o pipefail -o nounset

log()  { echo "[seed-demo-users] $*"; }
warn() { echo "[seed-demo-users] WARNING: $*" >&2; }
die()  { echo "[seed-demo-users] ERROR: $*" >&2; exit 1; }

usage() {
    sed -n '3,29p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

# Defaults matching the rest_api_cognito recipe's Cognito custom attributes.
ALICE_UID=1002
ALICE_GID=1002
BOB_UID=1003
BOB_GID=1003
HOME_BASE=/home

while [[ $# -gt 0 ]]; do
    case "$1" in
        --alice-uid)  ALICE_UID="${2:-}"; shift 2 ;;
        --alice-gid)  ALICE_GID="${2:-}"; shift 2 ;;
        --bob-uid)    BOB_UID="${2:-}"; shift 2 ;;
        --bob-gid)    BOB_GID="${2:-}"; shift 2 ;;
        --home-base)  HOME_BASE="${2:-}"; shift 2 ;;
        -h|--help)    usage 0 ;;
        *)            warn "Unknown argument: $1"; usage 1 ;;
    esac
done

# Validate numeric arguments
for var in ALICE_UID ALICE_GID BOB_UID BOB_GID; do
    if ! [[ "${!var}" =~ ^[0-9]+$ ]]; then
        die "${var}=${!var} is not a valid numeric ID"
    fi
done

# --- Create users idempotently -----------------------------------------------

ensure_user() {
    local username="$1" uid="$2" gid="$3" gecos="$4"

    # Create group if it does not exist
    if ! getent group "${username}" >/dev/null 2>&1; then
        log "Creating group ${username} (gid=${gid})"
        groupadd --gid "${gid}" "${username}"
    else
        existing_gid="$(getent group "${username}" | cut -d: -f3)"
        if [[ "${existing_gid}" != "${gid}" ]]; then
            warn "Group ${username} exists with gid=${existing_gid}, expected ${gid} — Cognito/Slurm identity mapping may be inconsistent"
        else
            log "Group ${username} already exists — skipping"
        fi
    fi

    # Create user if it does not exist.
    # --no-create-home: home dir comes from the EFS mount, not useradd.
    if ! id "${username}" >/dev/null 2>&1; then
        log "Creating user ${username} (uid=${uid}, gid=${gid})"
        useradd --uid "${uid}" --gid "${gid}" \
                --comment "${gecos}" \
                --shell /bin/bash \
                --no-create-home \
                "${username}"
    else
        existing_uid="$(id -u "${username}")"
        if [[ "${existing_uid}" != "${uid}" ]]; then
            warn "User ${username} exists with uid=${existing_uid}, expected ${uid} — Cognito/Slurm identity mapping may be inconsistent"
        else
            log "User ${username} already exists — skipping"
        fi
    fi

    # Ensure the home directory exists on the shared mount and is owned by the
    # user. configure-efs-homes mounts HOME_BASE but does not create per-user
    # dirs; a missing/unwritable home makes batch jobs fail (RaisedSignal:53).
    # Idempotent: mkdir -p and chown are safe to repeat.
    local home="${HOME_BASE%/}/${username}"
    if [[ ! -d "${home}" ]]; then
        log "Creating home directory ${home}"
        mkdir -p "${home}"
    fi
    chown "${uid}:${gid}" "${home}"
    chmod 0700 "${home}"
}

ensure_user "alice" "${ALICE_UID}" "${ALICE_GID}" "Alice Smith"
ensure_user "bob"   "${BOB_UID}"   "${BOB_GID}"   "Bob Jones"

log "Done. alice uid=${ALICE_UID} gid=${ALICE_GID}; bob uid=${BOB_UID} gid=${BOB_GID}; home-base=${HOME_BASE}"
