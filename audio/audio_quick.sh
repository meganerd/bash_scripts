#!/bin/bash

# Audio Router Aliases
# Quick shortcuts for common audio routing tasks

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
AUDIO_ROUTER="$SCRIPT_DIR/audio_router.sh"

case "${1:-}" in
    "spdif-to-model"|"stm")
        echo "Routing SPDIF to Model 12..."
        "$AUDIO_ROUTER" -i spdif -o model "${@:2}"
        ;;
    "spdif-to-model-low"|"stml")
        echo "Routing SPDIF to Model 12 (low latency)..."
        "$AUDIO_ROUTER" -i spdif -o model --low-latency "${@:2}"
        ;;
    "list"|"ls")
        "$AUDIO_ROUTER" --list "${@:2}"
        ;;
    "reset"|"stop")
        "$AUDIO_ROUTER" --reset "${@:2}"
        ;;
    "help"|"--help"|"-h"|"")
        cat << EOF
Audio Router Quick Commands

Usage: $0 COMMAND [OPTIONS]

COMMANDS:
    spdif-to-model, stm     Route SPDIF to Model 12
    spdif-to-model-low, stml Route SPDIF to Model 12 (low latency)
    list, ls                List all devices
    reset, stop             Reset all routing
    help                    Show this help

Any additional options are passed to the main script.

Examples:
    $0 stm                  # Route SPDIF to Model 12
    $0 stml                 # Route SPDIF to Model 12 (low latency)
    $0 list                 # List devices
    $0 reset                # Stop all routing

For advanced usage, use the main script directly:
    $AUDIO_ROUTER --help

EOF
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for available commands."
        exit 1
        ;;
esac
