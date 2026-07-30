#!/bin/bash
# tag-res-user.sh — Adds a res:User cost-allocation tag (the RES session owner)
# to the desktop instance it runs on. Registered on a project's
# scripts.linux.on_vdi_configured event. Runs as root after RES configures the VDI.
#
# Fails safe: never exits non-zero (would not fail the desktop over a billing tag).

set -u
TAG_KEY="res:User"
LAUNCH_ENV_FILE="/etc/launch_script_environment"
AWS_PROFILE_NAME="bootstrap_profile"

log() { echo "[tag-res-user] $*"; }

# Resolve owner: prefer OWNER_ID from the launch env file, fall back to IDEA_SESSION_OWNER.
OWNER=""
if [[ -f "${LAUNCH_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${LAUNCH_ENV_FILE}" || true
    OWNER="${OWNER_ID:-}"
fi
if [[ -z "${OWNER}" ]]; then
    OWNER="${IDEA_SESSION_OWNER:-}"
fi
if [[ -z "${OWNER}" ]]; then
    log "WARN: could not determine session owner; skipping res:User tag."
    exit 0
fi

# IMDSv2: get a token, then instance-id and region.
IMDS="http://169.254.169.254"
TOKEN="$(curl -sf -X PUT "${IMDS}/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300" || true)"
if [[ -z "${TOKEN}" ]]; then
    log "WARN: could not obtain IMDSv2 token; skipping res:User tag."
    exit 0
fi
HDR=(-H "X-aws-ec2-metadata-token: ${TOKEN}")
INSTANCE_ID="$(curl -sf "${HDR[@]}" "${IMDS}/latest/meta-data/instance-id" || true)"
REGION="$(curl -sf "${HDR[@]}" "${IMDS}/latest/dynamic/instance-identity/document" | grep -o '"region"[^,]*' | cut -d'"' -f4 || true)"
if [[ -z "${INSTANCE_ID}" || -z "${REGION}" ]]; then
    log "WARN: could not resolve instance-id/region from IMDS; skipping res:User tag."
    exit 0
fi

# Apply the tag using broker credentials (bootstrap_profile). Idempotent.
if aws ec2 create-tags \
    --profile "${AWS_PROFILE_NAME}" \
    --region "${REGION}" \
    --resources "${INSTANCE_ID}" \
    --tags "Key=${TAG_KEY},Value=${OWNER}"; then
    log "Applied ${TAG_KEY}=${OWNER} to ${INSTANCE_ID} in ${REGION}."
else
    log "WARN: create-tags failed for ${INSTANCE_ID}; continuing without failing the desktop."
fi
exit 0
