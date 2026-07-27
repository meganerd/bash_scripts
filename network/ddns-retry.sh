#!/usr/bin/env bash
# ddns-retry.sh — Check DHCP lease DDNS records and retry failed updates
#
# Parses dhcpd.leases to find active leases with ddns-fwd-name, verifies each
# resolves correctly via DNS, and retries failed updates via nsupdate with TSIG.
#
# Usage:
#   ddns-retry.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without making changes
#   --log-file PATH     Log file path (default: /var/log/ddns-retry.log)
#   --key-file PATH     TSIG key file path (default: /etc/dhcp/ddns-retry.key)
#   --leases-file PATH  dhcpd.leases path (default: /var/lib/dhcp/dhcpd.leases)
#   --dns-server IP     DNS server for verification queries (default: 192.168.76.250)
#   --external-server IP  External DNS server for DDNS updates (default: 100.69.197.72)
#   --help              Show this help message

set -euo pipefail

# --- Defaults ---
DRY_RUN=0
LOG_FILE="/var/log/ddns-retry.log"
KEY_FILE="/etc/dhcp/ddns-retry.key"
LEASES_FILE="/var/lib/dhcp/dhcpd.leases"
DNS_SERVER="192.168.76.250"
EXTERNAL_SERVER="100.69.197.72"
LOCAL_DOMAIN="lan.meganerd.ca"
REMOTE_DOMAIN="zarquon.space"
RETRY_TTL=300
MAX_RETRIES=3

# --- Logging ---
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${timestamp} [${level}] ${msg}"
    if [[ -w "$(dirname "${LOG_FILE}")" ]] || [[ -w "${LOG_FILE}" ]] || [[ ! -e "${LOG_FILE}" && -w "$(dirname "${LOG_FILE}")" ]]; then
        echo "${timestamp} [${level}] ${msg}" >> "${LOG_FILE}"
    fi
}

# --- Usage ---
usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --key-file)
            KEY_FILE="$2"
            shift 2
            ;;
        --leases-file)
            LEASES_FILE="$2"
            shift 2
            ;;
        --dns-server)
            DNS_SERVER="$2"
            shift 2
            ;;
        --external-server)
            EXTERNAL_SERVER="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# --- Validate prerequisites ---
if [[ ! -f "${LEASES_FILE}" ]]; then
    log "ERROR" "Leases file not found: ${LEASES_FILE}"
    exit 1
fi

if [[ ! -f "${KEY_FILE}" ]]; then
    log "ERROR" "TSIG key file not found: ${KEY_FILE}"
    exit 1
fi

if ! command -v nsupdate &>/dev/null; then
    log "ERROR" "nsupdate not found — install dnsutils"
    exit 1
fi

if ! command -v dig &>/dev/null; then
    log "ERROR" "dig not found — install dnsutils"
    exit 1
fi

# --- Parse leases file ---
# Extracts active leases: hostname, IP, and ddns-fwd-name
parse_leases() {
    local current_host="" current_ip="" current_ddns="" current_state=""
    local current_mac=""

    while IFS= read -r line; do
        # New lease block
        if [[ "${line}" =~ ^lease\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            # Output previous lease if it was active with ddns-fwd-name
            if [[ "${current_state}" == "active" && -n "${current_ddns}" && -n "${current_host}" ]]; then
                echo "${current_host}|${current_ip}|${current_ddns}|${current_mac}"
            fi
            current_ip="${BASH_REMATCH[1]}"
            current_host=""
            current_ddns=""
            current_state=""
            current_mac=""
        fi

        # Binding state
        local binding_re='binding state (.+);'
        if [[ "${line}" =~ ${binding_re} ]]; then
            current_state="${BASH_REMATCH[1]}"
        fi

        # Host name (from client-hostname)
        if [[ "${line}" =~ client-hostname\ \"([^\"]+)\" ]]; then
            current_host="${BASH_REMATCH[1]}"
        fi

        # ddns-fwd-name
        if [[ "${line}" =~ set\ ddns-fwd-name\ =\ \"([^\"]+)\" ]]; then
            current_ddns="${BASH_REMATCH[1]}"
        fi

        # MAC address
        local mac_re='hardware ethernet ([0-9a-fA-F:]+);'
        if [[ "${line}" =~ ${mac_re} ]]; then
            current_mac="${BASH_REMATCH[1]}"
        fi
    done < "${LEASES_FILE}"

    # Output last lease
    if [[ "${current_state}" == "active" && -n "${current_ddns}" && -n "${current_host}" ]]; then
        echo "${current_host}|${current_ip}|${current_ddns}|${current_mac}"
    fi
}

# --- Verify DNS record ---
# Returns 0 if hostname resolves to expected IP, 1 otherwise
verify_dns() {
    local hostname="$1"
    local expected_ip="$2"
    local domain="$3"

    local fqdn="${hostname}.${domain}"
    local resolved

    resolved="$(dig +short "${fqdn}" A "@${DNS_SERVER}" 2>/dev/null | head -1)"

    if [[ "${resolved}" == "${expected_ip}" ]]; then
        return 0
    fi
    return 1
}

# --- Retry DDNS update via nsupdate ---
retry_update() {
    local hostname="$1"
    local ip="$2"
    local domain="$3"
    local fqdn="${hostname}.${domain}"

    local server
    if [[ "${domain}" == "${REMOTE_DOMAIN}" ]]; then
        server="${EXTERNAL_SERVER}"
    else
        server="${DNS_SERVER}"
    fi

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "DRY-RUN" "Would update: ${fqdn} -> ${ip} on ${server}"
        return 0
    fi

    local attempt=0
    while (( attempt < MAX_RETRIES )); do
        attempt=$((attempt + 1))
        log "INFO" "Retry ${attempt}/${MAX_RETRIES}: ${fqdn} -> ${ip} on ${server}"

        if nsupdate -k "${KEY_FILE}" <<-NSEOF
server ${server}
zone ${domain}
update delete ${fqdn} A
update add ${fqdn} ${RETRY_TTL} A ${ip}
send
quit
NSEOF
        then
            log "SUCCESS" "Updated ${fqdn} -> ${ip} on ${server}"
            return 0
        else
            log "WARN" "Attempt ${attempt}/${MAX_RETRIES} failed for ${fqdn}"
            sleep $((attempt * 2))
        fi
    done

    log "ERROR" "All ${MAX_RETRIES} attempts failed for ${fqdn}"
    return 1
}

# --- Main ---
main() {
    log "INFO" "DDNS retry check starting (dry_run=${DRY_RUN})"

    local total=0
    local ok=0
    local retried=0
    local failed=0

    while IFS='|' read -r hostname ip ddns_name mac; do
        total=$((total + 1))

        # Determine domain from ddns-fwd-name
        local domain=""
        if [[ "${ddns_name}" == *".${REMOTE_DOMAIN}"* ]]; then
            domain="${REMOTE_DOMAIN}"
        elif [[ "${ddns_name}" == *".${LOCAL_DOMAIN}"* ]]; then
            domain="${LOCAL_DOMAIN}"
        else
            log "WARN" "Unknown domain in ddns-fwd-name: ${ddns_name} — skipping"
            continue
        fi

        # Verify local DNS (lan.meganerd.ca always checked via local server)
        if verify_dns "${hostname}" "${ip}" "${LOCAL_DOMAIN}"; then
            log "INFO" "OK: ${hostname}.${LOCAL_DOMAIN} -> ${ip}"
            ok=$((ok + 1))
        else
            log "WARN" "MISMATCH: ${hostname}.${LOCAL_DOMAIN} expected ${ip}"
            if retry_update "${hostname}" "${ip}" "${LOCAL_DOMAIN}"; then
                retried=$((retried + 1))
            else
                failed=$((failed + 1))
            fi
        fi

        # Verify remote DNS (zarquon.space checked via external server)
        if [[ "${domain}" == "${REMOTE_DOMAIN}" ]]; then
            if verify_dns "${hostname}" "${ip}" "${REMOTE_DOMAIN}"; then
                log "INFO" "OK: ${hostname}.${REMOTE_DOMAIN} -> ${ip}"
                ok=$((ok + 1))
            else
                log "WARN" "MISMATCH: ${hostname}.${REMOTE_DOMAIN} expected ${ip}"
                if retry_update "${hostname}" "${ip}" "${REMOTE_DOMAIN}"; then
                    retried=$((retried + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi
    done < <(parse_leases)

    log "INFO" "DDNS retry check complete: total=${total} ok=${ok} retried=${retried} failed=${failed}"

    if (( failed > 0 )); then
        exit 1
    fi
    exit 0
}

main "$@"
