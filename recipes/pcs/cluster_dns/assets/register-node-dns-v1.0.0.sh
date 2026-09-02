#!/usr/bin/env bash
#
# register-node-dns-v1.0.0.sh — AWS PCS node lifecycle action (community example)
#
# Gives a PCS node a resolvable name. On boot it:
#   1. Registers <PCS_NODE_ID>.<zone> -> the node's primary IPv4 in a Route53
#      private hosted zone (an UPSERT, so it is idempotent).
#   2. Adds <zone> to the node's local DNS search list, so peers that address the
#      node by its short Slurm name (for example "compute-2", as MPI and srun do)
#      resolve it. The method is chosen to match the AMI's resolver, in order:
#        - systemd-resolved (Ubuntu 24 PCS-ready DLAMI and AL2023 x86 sample AMI):
#          resolved.conf.d drop-in
#        - NetworkManager   (e.g. RHEL/Rocky 9, or an AMI without resolved):
#          nmcli ipv4.dns-search
#        - anything else: append "search <zone>" to /etc/resolv.conf (best-effort)
#
# Pair it with a per-cluster private hosted zone (see the cluster_dns recipe). The
# node instance role needs route53:ChangeResourceRecordSets on that zone.
#
# The action is BEST-EFFORT: on any missing prerequisite or failed call it logs a
# warning and exits 0, so a DNS hiccup never terminates a node. Pair with
# onError: CONTINUE. Cleanup of records for terminated nodes is handled separately
# by the reconcile Lambda in the cluster_dns recipe (this script never deletes).
#
# Prerequisites: awscli, curl (both on the sample AMI and the PCS-ready DLAMI).
# Suggested execution policy: EVERY_BOOT (every step is idempotent; re-asserts the
#   record if it was ever removed).
# Suggested onError: CONTINUE (best-effort).
#
# Usage:
#   register-node-dns-v1.0.0.sh --zone-id ZONE_ID --zone-name ZONE [--ttl SECONDS]
#
# Flags:
#   --zone-id ID      Route53 hosted zone ID (required).
#   --zone-name ZONE  Zone name, e.g. pcs_abc123.pcs.local (required).
#   --ttl SECONDS     Record TTL (default: 60).
#   -h, --help        Show this help and exit.

set -o errexit -o pipefail -o nounset

log()  { echo "[register-node-dns] $*"; }
warn() { echo "[register-node-dns] WARNING: $*" >&2; }

usage() {
    sed -n '3,38p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
    exit "${1:-0}"
}

ZONE_ID=""
ZONE_NAME=""
TTL="60"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zone-id)   ZONE_ID="${2:-}";   shift 2 ;;
        --zone-name) ZONE_NAME="${2:-}"; shift 2 ;;
        --ttl)       TTL="${2:-}";       shift 2 ;;
        -h|--help)   usage 0 ;;
        *)           warn "Unknown argument: $1"; usage 1 ;;
    esac
done

NODE_ID="${PCS_NODE_ID:-}"

# --- IMDSv2 helper -----------------------------------------------------------
# Short timeouts so the script fails fast (and, being best-effort, skips) when
# IMDS is unreachable, rather than stalling node bootstrap.
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

# --- Set the local DNS search domain ----------------------------------------
# Idempotent across boots. Detects the resolver stack and uses the durable method
# for each; the naive "echo >> /etc/resolv.conf" is only a last resort because a
# resolver manager rewrites that file on the next network event.
set_search_domain() {
    local zone="$1"

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log "systemd-resolved detected; writing resolved.conf.d drop-in"
        mkdir -p /etc/systemd/resolved.conf.d
        printf '[Resolve]\nDomains=%s\n' "${zone}" \
            > /etc/systemd/resolved.conf.d/10-pcs-search.conf
        systemctl restart systemd-resolved 2>/dev/null \
            || warn "could not restart systemd-resolved"
        return 0
    fi

    if command -v nmcli >/dev/null 2>&1; then
        local dev con
        dev="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
        if [[ -n "${dev}" ]]; then
            con="$(nmcli -t -g GENERAL.CONNECTION device show "${dev}" 2>/dev/null || true)"
        fi
        if [[ -n "${con:-}" ]]; then
            log "NetworkManager detected; setting ipv4.dns-search on '${con}'"
            # Set the absolute value (not +) so repeated boots stay idempotent.
            nmcli connection modify "${con}" ipv4.dns-search "${zone}" 2>/dev/null \
                || { warn "nmcli modify failed"; return 1; }
            # reapply updates DNS without deactivating the link (avoids a boot-time blip).
            nmcli device reapply "${dev}" 2>/dev/null \
                || warn "nmcli device reapply failed; change applies on next network event"
            return 0
        fi
        warn "nmcli present but no active connection found for device '${dev:-unknown}'"
    fi

    warn "no managed resolver detected; appending 'search ${zone}' to /etc/resolv.conf"
    if ! grep -qE "^search .*(^| )${zone}( |\$)" /etc/resolv.conf 2>/dev/null; then
        if grep -qE '^search ' /etc/resolv.conf 2>/dev/null; then
            sed -i -E "s/^(search .*)\$/\1 ${zone}/" /etc/resolv.conf
        else
            echo "search ${zone}" >> /etc/resolv.conf
        fi
    fi
}

# --- Validate inputs (best-effort: warn and exit 0 on anything missing) ------
[[ -n "${ZONE_ID}" ]]   || { warn "--zone-id is required. Skipping.";   exit 0; }
[[ -n "${ZONE_NAME}" ]] || { warn "--zone-name is required. Skipping."; exit 0; }
[[ -n "${NODE_ID}" ]]   || { warn "PCS_NODE_ID is not set. Skipping.";  exit 0; }

if ! command -v aws >/dev/null 2>&1; then
    warn "AWS CLI not found on this AMI. Cannot register DNS. Skipping."
    warn "Install 'awscli' in your AMI to enable node DNS registration."
    exit 0
fi

IP="$(imds_get "local-ipv4")"
[[ -n "${IP}" ]] || { warn "Could not read local-ipv4 from IMDSv2. Skipping."; exit 0; }

RECORD="${NODE_ID}.${ZONE_NAME%.}"

# --- Register the record (UPSERT; best-effort) -------------------------------
log "Registering ${RECORD} -> ${IP} (TTL ${TTL}) in zone ${ZONE_ID}"

batch="$(mktemp)"
trap 'rm -f "${batch}"' EXIT
cat > "${batch}" <<JSON
{
  "Comment": "PCS node ${NODE_ID} self-registration",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RECORD}",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [{ "Value": "${IP}" }]
      }
    }
  ]
}
JSON

if aws route53 change-resource-record-sets \
    --hosted-zone-id "${ZONE_ID}" \
    --change-batch "file://${batch}" >/dev/null 2>/tmp/register-node-dns.err; then
    log "Record registered."
else
    warn "change-resource-record-sets failed (best-effort; the node continues):"
    warn "$(cat /tmp/register-node-dns.err 2>/dev/null || true)"
    warn "Confirm the node instance role allows route53:ChangeResourceRecordSets on this zone."
fi

# --- Set the search domain so short names resolve (best-effort) --------------
set_search_domain "${ZONE_NAME%.}" || warn "Could not set DNS search domain."

log "Done."
