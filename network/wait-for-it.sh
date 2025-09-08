#!/usr/bin/env bash
# Use this script to test if a given TCP host/port are available

WAITFORIT_cmdname=${0##*/}

echoerr() { if [[ $WAITFORIT_QUIET -ne 1 ]]; then echo "$@" 1>&2; fi }

# Detect if input looks like an IP address (including malformed ones)
is_ip_address() {
    local input=$1

    # IPv4 pattern check (exactly 4 numeric parts separated by dots)
    if [[ $input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi

    # Malformed IPv4 pattern check (numeric parts separated by dots, but not exactly 4)
    if [[ $input =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        return 0
    fi

    # IPv6 pattern check (basic)
    if [[ $input =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] || [[ $input == "::1" ]] || [[ $input == "::" ]]; then
        return 0
    fi

    return 1
}

# Validate IP address format and structure
validate_ip_format() {
    local ip=$1

    # IPv4 validation (must have exactly 4 octets)
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local IFS='.'
        read -ra OCTETS <<< "$ip"

        # Must have exactly 4 octets
        if [[ ${#OCTETS[@]} -ne 4 ]]; then
            return 1
        fi

        for octet in "${OCTETS[@]}"; do
            # Check for leading zeros (except for "0")
            if [[ ${#octet} -gt 1 && $octet =~ ^0 ]]; then
                return 1
            fi
            # Check if octet is a valid number and within range
            if ! [[ $octet =~ ^[0-9]+$ ]] || (( octet > 255 )); then
                return 1
            fi
        done
        return 0
    # Check for malformed IPv4 (wrong number of octets)
    elif [[ $ip =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        return 1  # Looks like IPv4 but wrong format
    # IPv6 validation (basic check for colon presence and valid characters)
    elif [[ $ip =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]] || [[ $ip == "::1" ]] || [[ $ip == "::" ]]; then
        return 0
    fi

    return 1
}

# Validate hostname format
validate_hostname_format() {
    local hostname=$1

    # Check length (max 253 characters)
    if [[ ${#hostname} -gt 253 ]]; then
        return 1
    fi

    # Check for valid hostname pattern
    # Hostnames can contain letters, digits, hyphens, and dots
    # Cannot start or end with hyphen
    # Cannot have consecutive dots
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        # Additional check: no label can start or end with hyphen
        local IFS='.'
        read -ra LABELS <<< "$hostname"
        for label in "${LABELS[@]}"; do
            if [[ $label =~ ^- ]] || [[ $label =~ -$ ]]; then
                return 1
            fi
        done
        return 0
    fi

    # Also allow single-label hostnames (short names without dots)
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    fi

    return 1
}

# Check if hostname resolves via DNS
check_hostname_dns() {
    local hostname=$1

    # Try to resolve the hostname using nslookup, dig, or host (in order of preference)
    if command -v nslookup >/dev/null 2>&1; then
        if nslookup "$hostname" >/dev/null 2>&1; then
            return 0
        fi
    elif command -v dig >/dev/null 2>&1; then
        if dig "$hostname" +short >/dev/null 2>&1; then
            return 0
        fi
    elif command -v host >/dev/null 2>&1; then
        if host "$hostname" >/dev/null 2>&1; then
            return 0
        fi
    else
        # Fallback: try to use getent hosts if available
        if command -v getent >/dev/null 2>&1; then
            if getent hosts "$hostname" >/dev/null 2>&1; then
                return 0
            fi
        else
            # Last resort: use /etc/hosts lookup via grep
            if grep -q "^[^#]*[[:space:]]$hostname[[:space:]]*$\|^[^#]*[[:space:]]$hostname$" /etc/hosts 2>/dev/null; then
                return 0
            fi
        fi
    fi

    return 1
}

# Main validation function
validate_host() {
    local host=$1

    if is_ip_address "$host"; then
        # It looks like an IP address, validate format
        if validate_ip_format "$host"; then
            return 0
        else
            echoerr "Error: '$host' is not a valid IP address format."
            return 1
        fi
    else
        # It looks like a hostname, validate format and DNS
        if ! validate_hostname_format "$host"; then
            echoerr "Error: '$host' is not a valid hostname format."
            return 1
        fi

        if ! check_hostname_dns "$host"; then
            echoerr "Error: hostname '$host' does not resolve to an IP address."
            return 1
        fi

        return 0
    fi
}

usage()
{
    cat << USAGE >&2
Usage:
    $WAITFORIT_cmdname host:port [-s] [-t timeout] [-- command args]
    -h HOST | --host=HOST       Host or IP under test
    -p PORT | --port=PORT       TCP port under test
                                Alternatively, you specify the host and port as host:port
    -s | --strict               Only execute subcommand if the test succeeds
    -q | --quiet                Don't output any status messages
    -t TIMEOUT | --timeout=TIMEOUT
                                Timeout in seconds, zero for no timeout
    -- COMMAND ARGS             Execute command with args after the test finishes
USAGE
    exit 1
}

wait_for()
{
    if [[ $WAITFORIT_TIMEOUT -gt 0 ]]; then
        echoerr "$WAITFORIT_cmdname: waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    else
        echoerr "$WAITFORIT_cmdname: waiting for $WAITFORIT_HOST:$WAITFORIT_PORT without a timeout"
    fi
    WAITFORIT_start_ts=$(date +%s)
    while :
    do
        if [[ $WAITFORIT_ISBUSY -eq 1 ]]; then
            # Capture both stdout and stderr to check for boot error messages
            WAITFORIT_output=$(nc -z "$WAITFORIT_HOST" "$WAITFORIT_PORT" 2>&1)
            WAITFORIT_result=$?
        else
            # Capture stderr to check for boot error messages
            WAITFORIT_output=$(bash -c "echo -n > /dev/tcp/$WAITFORIT_HOST/$WAITFORIT_PORT" 2>&1)
            WAITFORIT_result=$?
        fi

        # Check for system boot error message
        if [[ "$WAITFORIT_output" == *"System is booting up. Unprivileged users are not permitted to log in yet"* ]]; then
            echoerr "$WAITFORIT_cmdname: System is booting up, continuing to wait for $WAITFORIT_HOST:$WAITFORIT_PORT"
            sleep 1
            continue
        fi

        if [[ $WAITFORIT_result -eq 0 ]]; then
            WAITFORIT_end_ts=$(date +%s)
            echoerr "$WAITFORIT_cmdname: $WAITFORIT_HOST:$WAITFORIT_PORT is available after $((WAITFORIT_end_ts - WAITFORIT_start_ts)) seconds"
            break
        fi
        sleep 1
    done
    return $WAITFORIT_result
}

wait_for_wrapper()
{
    # In order to support SIGINT during timeout: http://unix.stackexchange.com/a/57692
    if [[ $WAITFORIT_QUIET -eq 1 ]]; then
        timeout $WAITFORIT_BUSYTIMEFLAG $WAITFORIT_TIMEOUT $0 --quiet --child --host="$WAITFORIT_HOST" --port="$WAITFORIT_PORT" --timeout="$WAITFORIT_TIMEOUT" &
    else
        timeout $WAITFORIT_BUSYTIMEFLAG $WAITFORIT_TIMEOUT $0 --child --host="$WAITFORIT_HOST" --port="$WAITFORIT_PORT" --timeout="$WAITFORIT_TIMEOUT" &
    fi
    WAITFORIT_PID=$!
    trap "kill -INT -$WAITFORIT_PID" INT
    wait $WAITFORIT_PID
    WAITFORIT_RESULT=$?
    if [[ $WAITFORIT_RESULT -ne 0 ]]; then
        echoerr "$WAITFORIT_cmdname: timeout occurred after waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    fi
    return $WAITFORIT_RESULT
}

# process arguments
while [[ $# -gt 0 ]]
do

    case "$1" in
        --child)
        WAITFORIT_CHILD=1

        shift 1
        ;;
        -q | --quiet)
        WAITFORIT_QUIET=1
        shift 1
        ;;
        -s | --strict)
        WAITFORIT_STRICT=1
        shift 1
        ;;
        -h)
        WAITFORIT_HOST="$2"

        if [[ $WAITFORIT_HOST == "" ]]; then break; fi
        shift 2
        ;;
        --host=*)
        WAITFORIT_HOST="${1#*=}"

        shift 1
        ;;
        *:* )
        # Handle IPv6 addresses in brackets: [::1]:80
        if [[ $1 =~ ^\[(.+)\]:([0-9]+)$ ]]; then
            WAITFORIT_HOST="${BASH_REMATCH[1]}"
            WAITFORIT_PORT="${BASH_REMATCH[2]}"

        else
            # Handle IPv4 and hostnames: host:port
            WAITFORIT_hostport=(${1//:/ })
            WAITFORIT_HOST=${WAITFORIT_hostport[0]}
            WAITFORIT_PORT=${WAITFORIT_hostport[1]}

        fi
        shift 1
        ;;
        -p)
        WAITFORIT_PORT="$2"
        if [[ $WAITFORIT_PORT == "" ]]; then break; fi
        shift 2
        ;;
        --port=*)
        WAITFORIT_PORT="${1#*=}"
        shift 1
        ;;
        -t)
        WAITFORIT_TIMEOUT="$2"
        if [[ $WAITFORIT_TIMEOUT == "" ]]; then break; fi
        shift 2
        ;;
        --timeout=*)
        WAITFORIT_TIMEOUT="${1#*=}"
        shift 1
        ;;
        --)
        shift
        WAITFORIT_CLI=("$@")
        break
        ;;
        --help)
        usage
        ;;
        *)
        echoerr "Unknown argument: $1"
        usage
        ;;
    esac
done

if [[ "$WAITFORIT_HOST" == "" || "$WAITFORIT_PORT" == "" ]]; then
    echoerr "Error: you need to provide a host and port to test."
    usage
fi

# Validate host format and DNS resolution (for both parent and child processes)
if ! validate_host "$WAITFORIT_HOST"; then
    exit 1
fi


WAITFORIT_TIMEOUT=${WAITFORIT_TIMEOUT:-15}
WAITFORIT_STRICT=${WAITFORIT_STRICT:-0}
WAITFORIT_CHILD=${WAITFORIT_CHILD:-0}
WAITFORIT_QUIET=${WAITFORIT_QUIET:-0}

# Check to see if timeout is from busybox?
WAITFORIT_TIMEOUT_PATH=$(type -p timeout)
WAITFORIT_TIMEOUT_PATH=$(realpath $WAITFORIT_TIMEOUT_PATH 2>/dev/null || readlink -f $WAITFORIT_TIMEOUT_PATH)

WAITFORIT_BUSYTIMEFLAG=""
if [[ $WAITFORIT_TIMEOUT_PATH =~ "busybox" ]]; then
    WAITFORIT_ISBUSY=1
    # Check if busybox timeout uses -t flag
    # (recent Alpine versions don't support -t anymore)
    if timeout 2>&1 | grep -q -e '-t '; then
        WAITFORIT_BUSYTIMEFLAG="-t"
    fi
else
    WAITFORIT_ISBUSY=0
fi

if [[ $WAITFORIT_CHILD -gt 0 ]]; then
    wait_for
    WAITFORIT_RESULT=$?
    exit $WAITFORIT_RESULT
else
    if [[ $WAITFORIT_TIMEOUT -gt 0 ]]; then
        wait_for_wrapper
        WAITFORIT_RESULT=$?
    else
        wait_for
        WAITFORIT_RESULT=$?
    fi
fi

if [[ $WAITFORIT_CLI != "" ]]; then
    if [[ $WAITFORIT_RESULT -ne 0 && $WAITFORIT_STRICT -eq 1 ]]; then
        echoerr "$WAITFORIT_cmdname: strict mode, refusing to execute subprocess"
        exit $WAITFORIT_RESULT
    fi
    exec "${WAITFORIT_CLI[@]}"
else
    exit $WAITFORIT_RESULT
fi
