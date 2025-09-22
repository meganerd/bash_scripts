#!/bin/bash

# Audio Router Script
# Routes audio between SPDIF and various audio devices using PulseAudio/PipeWire
# Author: Generated for audio routing tasks

set -euo pipefail

# Default values
LATENCY_MS=50
LOW_LATENCY=false
INPUTS=()
OUTPUTS=()
LIST_DEVICES=false
RESET=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Audio Router Script - Route audio between devices using PulseAudio/PipeWire

Usage: $0 [OPTIONS]

OPTIONS:
    -i, --input DEVICE      Input device name or pattern (can be used multiple times)
    -o, --output DEVICE     Output device name or pattern (can be used multiple times)
    -l, --list             List all available audio devices
    -r, --reset            Reset all audio routing (unload all loopback modules)
    --low-latency          Enable low latency mode (10ms instead of 50ms)
    --high-latency         Disable low latency mode (use 50ms latency)
    --latency MS           Set custom latency in milliseconds (default: 50)
    -v, --verbose          Enable verbose output
    -h, --help             Show this help message

EXAMPLES:
    # List all devices
    $0 --list

    # Route SPDIF to Model 12
    $0 -i spdif -o model

    # Route multiple inputs to multiple outputs
    $0 -i spdif -i usb -o model -o hdmi

    # Use low latency
    $0 -i spdif -o model --low-latency

    # Custom latency
    $0 -i spdif -o model --latency 25

    # Reset all routing
    $0 --reset

DEVICE MATCHING:
    Device names are matched as case-insensitive substrings.
    For example:
    - 'spdif' matches devices containing 'spdif'
    - 'model' matches devices containing 'model'
    - 'usb' matches devices containing 'usb'
    - Full device names can also be used

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check if PulseAudio/PipeWire is running
check_audio_system() {
    if ! command -v pactl &> /dev/null; then
        log_error "pactl command not found. Please install PulseAudio or PipeWire."
        exit 1
    fi

    if ! pactl info &> /dev/null; then
        log_error "PulseAudio/PipeWire is not running."
        exit 1
    fi

    local server_info
    server_info=$(pactl info | grep "Server Name" || echo "Unknown")
    log_verbose "Audio system: $server_info"
}

# List all audio devices
list_devices() {
    log_info "Available Audio Sources (Inputs):"
    echo "========================================="
    pactl list sources short | while read -r id name driver format status; do
        if [[ ! "$name" =~ \.monitor$ ]]; then  # Skip monitor sources
            local desc
            desc=$(pactl list sources | grep -A 20 "Name: $name" | grep "Description:" | cut -d: -f2- | xargs || echo "No description")
            printf "%-50s [%s]\n" "$name" "$desc"
        fi
    done

    echo ""
    log_info "Available Audio Sinks (Outputs):"
    echo "=========================================="
    pactl list sinks short | while read -r id name driver format status; do
        local desc
        desc=$(pactl list sinks | grep -A 20 "Name: $name" | grep "Description:" | cut -d: -f2- | xargs || echo "No description")
        printf "%-50s [%s]\n" "$name" "$desc"
    done
}

# Find device by pattern
find_device() {
    local pattern="$1"
    local device_type="$2"  # "sources" or "sinks"
    local found_devices=()

    log_verbose "Searching for $device_type matching pattern: '$pattern'"

    while read -r id name driver format status; do
        if [[ "$device_type" == "sources" && "$name" =~ \.monitor$ ]]; then
            continue  # Skip monitor sources
        fi
        
        if [[ "$name" =~ $pattern ]] || [[ "${name,,}" =~ ${pattern,,} ]]; then
            found_devices+=("$name")
            log_verbose "Found matching device: $name"
        fi
    done < <(pactl list "$device_type" short)

    if [[ ${#found_devices[@]} -eq 0 ]]; then
        log_error "No $device_type found matching pattern: '$pattern'"
        return 1
    elif [[ ${#found_devices[@]} -gt 1 ]]; then
        log_warning "Multiple $device_type found matching pattern '$pattern':"
        for device in "${found_devices[@]}"; do
            log_warning "  - $device"
        done
        log_warning "Using first match: ${found_devices[0]}"
    fi

    echo "${found_devices[0]}"
}

# Reset all loopback modules
reset_audio_routing() {
    log_info "Resetting all audio routing..."
    
    local modules
    modules=$(pactl list modules short | grep "module-loopback" | cut -f1 || true)
    
    if [[ -z "$modules" ]]; then
        log_info "No loopback modules found to remove."
        return 0
    fi

    local count=0
    while read -r module_id; do
        if [[ -n "$module_id" ]]; then
            log_verbose "Unloading module: $module_id"
            if pactl unload-module "$module_id"; then
                ((count++))
            else
                log_warning "Failed to unload module: $module_id"
            fi
        fi
    done <<< "$modules"

    log_success "Reset complete. Removed $count loopback module(s)."
}

# Create audio routing
create_routing() {
    local input_device="$1"
    local output_device="$2"
    local latency="$3"

    log_info "Creating route: $input_device -> $output_device (latency: ${latency}ms)"
    
    local module_id
    if module_id=$(pactl load-module module-loopback "source=$input_device" "sink=$output_device" "latency_msec=$latency" 2>/dev/null); then
        log_success "Route created successfully (module ID: $module_id)"
        return 0
    else
        log_error "Failed to create route: $input_device -> $output_device"
        return 1
    fi
}

# Main routing function
setup_routing() {
    local resolved_inputs=()
    local resolved_outputs=()

    # Resolve input devices
    for pattern in "${INPUTS[@]}"; do
        if resolved_input=$(find_device "$pattern" "sources"); then
            resolved_inputs+=("$resolved_input")
        else
            log_error "Could not resolve input device: $pattern"
            exit 1
        fi
    done

    # Resolve output devices
    for pattern in "${OUTPUTS[@]}"; do
        if resolved_output=$(find_device "$pattern" "sinks"); then
            resolved_outputs+=("$resolved_output")
        else
            log_error "Could not resolve output device: $pattern"
            exit 1
        fi
    done

    # Set latency based on flags
    local effective_latency=$LATENCY_MS
    if [[ "$LOW_LATENCY" == true ]]; then
        effective_latency=10
        log_info "Using low latency mode: ${effective_latency}ms"
    fi

    # Create routing for each input-output combination
    local success_count=0
    local total_routes=$((${#resolved_inputs[@]} * ${#resolved_outputs[@]}))

    for input in "${resolved_inputs[@]}"; do
        for output in "${resolved_outputs[@]}"; do
            if create_routing "$input" "$output" "$effective_latency"; then
                ((success_count++))
            fi
        done
    done

    if [[ $success_count -eq $total_routes ]]; then
        log_success "All $total_routes route(s) created successfully!"
    else
        log_warning "Created $success_count out of $total_routes route(s)."
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUTS+=("$2")
            shift 2
            ;;
        -o|--output)
            OUTPUTS+=("$2")
            shift 2
            ;;
        -l|--list)
            LIST_DEVICES=true
            shift
            ;;
        -r|--reset)
            RESET=true
            shift
            ;;
        --low-latency)
            LOW_LATENCY=true
            shift
            ;;
        --high-latency)
            LOW_LATENCY=false
            shift
            ;;
        --latency)
            LATENCY_MS="$2"
            if ! [[ "$LATENCY_MS" =~ ^[0-9]+$ ]]; then
                log_error "Latency must be a positive integer"
                exit 1
            fi
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    check_audio_system

    if [[ "$LIST_DEVICES" == true ]]; then
        list_devices
        exit 0
    fi

    if [[ "$RESET" == true ]]; then
        reset_audio_routing
        exit 0
    fi

    # Check if we have inputs and outputs for routing
    if [[ ${#INPUTS[@]} -eq 0 || ${#OUTPUTS[@]} -eq 0 ]]; then
        if [[ ${#INPUTS[@]} -eq 0 && ${#OUTPUTS[@]} -eq 0 ]]; then
            log_error "No inputs or outputs specified. Use --help for usage information."
        elif [[ ${#INPUTS[@]} -eq 0 ]]; then
            log_error "No input devices specified. Use -i/--input to specify input devices."
        else
            log_error "No output devices specified. Use -o/--output to specify output devices."
        fi
        exit 1
    fi

    setup_routing
}

# Run main function
main "$@"
