#!/bin/bash
#
# monitor-control.sh - Send commands to LG monitor via serial port
# Compatible with models: 43UN700, 43UN700T, 43BN70U
#
# Usage: ./monitor-control.sh [options] <command> [parameters]
#
# Options:
#   -p, --port PORT    Specify serial port (default: /dev/ttyUSB0)
#   -i, --id ID        Set monitor ID (default: 01)
#   -h, --help         Show this help message
#
# Commands:
#   power              Power on/off (parameters: on, off)
#   input              Select input source (parameters: hdmi1, hdmi2, hdmi3, hdmi4, dp, usbc)
#   volume             Set volume (parameters: 0-64 or mute, unmute)
#   brightness         Set brightness (parameters: 0-64)
#   contrast           Set contrast (parameters: 0-64)
#   picture-mode       Set picture mode (parameters: custom, vivid, reader, cinema, etc.)
#   reset              Reset settings (parameters: picture, factory)
#   list-commands      Show all available commands
#
# Examples:
#   ./monitor-control.sh power on
#   ./monitor-control.sh -p /dev/ttyUSB1 volume 30
#   ./monitor-control.sh -i 02 input hdmi1
#   ./monitor-control.sh list-commands

# Default values
PORT="/dev/ttyUSB0"
MONITOR_ID="01"

# Communication parameters
# Baud rate: 9600 bps (UART)
# Data length: 8 bits
# Parity: None
# Stop bit: 1 bit
# Communication code: ASCII code

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -i|--id)
            MONITOR_ID="$2"
            shift 2
            ;;
        -h|--help)
            # Only show the help text at the top of the file
            sed -n '2,/^$/p' "$0" | grep "^#" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Check if serial port exists
if [ ! -e "$PORT" ]; then
    echo "Warning: Serial port $PORT does not exist."
    echo "Will attempt to use it anyway in case it's created later."
    echo "Please connect the device or specify a different port with -p option."
fi

# Function to send command to monitor
send_command() {
    local cmd1="$1"
    local cmd2="$2"
    local data="$3"
    
    # Format: [Command1][Command2][ ][Set ID][ ][Data][Cr]
    # The format requires spaces between components and a carriage return at the end
    # Make sure MONITOR_ID is padded to 2 digits
    local padded_id=$(printf "%02d" "$MONITOR_ID")
    local command="${cmd1}${cmd2} ${padded_id} ${data}\r"
    
    # For debugging
    echo "DEBUG: Sending command: ${command}"
    
    # Configure serial port before sending
    if ! stty -F "$PORT" 9600 cs8 -cstopb -parenb 2>/dev/null; then
        echo "Warning: Failed to configure serial port $PORT"
        echo "Make sure the device is connected and you have permission to access it."
    fi
    
    # Send command to serial port
    if ! echo -ne "$command" > "$PORT" 2>/dev/null; then
        echo "Warning: Failed to send command to $PORT"
        echo "Make sure the device is connected and you have permission to access it."
    fi
    
    # Wait for response (optional)
    sleep 0.5
    
    # Read response (optional)
    # cat "$PORT"
}

# Command reference list based on the PDF
declare -A COMMANDS
COMMANDS=(
    ["power"]="k"
    ["screen-mute"]="k"
    ["input-main"]="x"
    ["input-sub"]="x"
    ["input-sub2"]="x"
    ["input-sub3"]="x"
    ["aspect-ratio-main"]="x"
    ["aspect-ratio-sub"]="x"
    ["aspect-ratio-sub2"]="x"
    ["aspect-ratio-sub3"]="x"
    ["pbp-pip"]="k"
    ["pip-size"]="k"
    ["main-sub-change"]="m"
    ["picture-mode"]="d"
    ["brightness"]="k"
    ["contrast"]="k"
    ["sharpness"]="k"
    ["brightness-stabilization"]="m"
    ["super-resolution"]="m"
    ["black-level"]="m"
    ["hdmi-deep-color"]="m"
    ["dfc"]="m"
    ["response-time"]="m"
    ["black-stabilizer"]="m"
    ["uniformity"]="m"
    ["gamma"]="m"
    ["color-temp"]="k"
    ["red-gain"]="j"
    ["green-gain"]="j"
    ["blue-gain"]="j"
    ["language"]="f"
    ["energy-saving"]="m"
    ["auto-screen-off"]="m"
    ["displayport-version"]="m"
    ["osd-lock"]="k"
    ["reset"]="f"
    ["volume-mute"]="k"
    ["volume"]="k"
)

# Data values for commands
declare -A DATA_VALUES
DATA_VALUES=(
    ["power.on"]="01"
    ["power.off"]="00"
    
    ["input.hdmi1"]="90"
    ["input.hdmi2"]="91"
    ["input.hdmi3"]="92"
    ["input.hdmi4"]="93"
    ["input.dp"]="C0"
    ["input.usbc"]="E0"
    
    ["volume-mute.on"]="00"
    ["volume-mute.off"]="01"
    
    ["picture-mode.custom"]="00"
    ["picture-mode.vivid"]="01"
    ["picture-mode.reader"]="02"
    ["picture-mode.cinema"]="03"
    ["picture-mode.fps"]="08"
    ["picture-mode.rts"]="0A"
    
    ["reset.picture"]="00"
    ["reset.factory"]="01"
)

# Function to convert decimal to hex
dec_to_hex() {
    printf "%02X" "$1"
}

# Function to list all available commands
list_commands() {
    echo "Available commands:"
    echo "==================="
    echo "power: on, off"
    echo "input: hdmi1, hdmi2, hdmi3, hdmi4, dp, usbc"
    echo "volume: 0-64, mute, unmute"
    echo "brightness: 0-64"
    echo "contrast: 0-64"
    echo "picture-mode: custom, vivid, reader, cinema, fps, rts"
    echo "reset: picture, factory"
    echo
    echo "For more commands, refer to the monitor's user manual."
}

# Main command processing
if [ $# -lt 1 ]; then
    echo "Error: No command specified."
    echo "Use --help for usage information."
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    "power")
        if [ "$1" = "on" ]; then
            send_command "${COMMANDS["power"]}" "a" "01"
            echo "Sending power on command"
        elif [ "$1" = "off" ]; then
            send_command "${COMMANDS["power"]}" "a" "00"
            echo "Sending power off command"
        else
            echo "Invalid parameter for power. Use 'on' or 'off'."
            exit 1
        fi
        ;;
        
    "input")
        case "$1" in
            "hdmi1") data="90" ;;
            "hdmi2") data="91" ;;
            "hdmi3") data="92" ;;
            "hdmi4") data="93" ;;
            "dp") data="C0" ;;
            "usbc") data="E0" ;;
            *)
                echo "Invalid input source. Use hdmi1, hdmi2, hdmi3, hdmi4, dp, or usbc."
                exit 1
                ;;
        esac
        send_command "${COMMANDS["input-main"]}" "b" "$data"
        echo "Switching input to $1"
        ;;
        
    "volume")
        if [ "$1" = "mute" ]; then
            send_command "${COMMANDS["volume-mute"]}" "e" "00"
            echo "Muting volume"
        elif [ "$1" = "unmute" ]; then
            send_command "${COMMANDS["volume-mute"]}" "e" "01"
            echo "Unmuting volume"
        elif [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 0 ] && [ "$1" -le 64 ]; then
            hex_vol=$(dec_to_hex "$1")
            send_command "${COMMANDS["volume"]}" "f" "$hex_vol"
            echo "Setting volume to $1"
        else
            echo "Invalid volume parameter. Use a number between 0-64, or 'mute'/'unmute'."
            exit 1
        fi
        ;;
        
    "brightness")
        if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 0 ] && [ "$1" -le 64 ]; then
            hex_val=$(dec_to_hex "$1")
            send_command "${COMMANDS["brightness"]}" "h" "$hex_val"
            echo "Setting brightness to $1"
        else
            echo "Invalid brightness parameter. Use a number between 0-64."
            exit 1
        fi
        ;;
        
    "contrast")
        if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 0 ] && [ "$1" -le 64 ]; then
            hex_val=$(dec_to_hex "$1")
            send_command "${COMMANDS["contrast"]}" "g" "$hex_val"
            echo "Setting contrast to $1"
        else
            echo "Invalid contrast parameter. Use a number between 0-64."
            exit 1
        fi
        ;;
        
    "picture-mode")
        case "$1" in
            "custom") data="00" ;;
            "vivid") data="01" ;;
            "reader") data="02" ;;
            "cinema") data="03" ;;
            "fps") data="08" ;;
            "rts") data="0A" ;;
            *)
                echo "Invalid picture mode. Use custom, vivid, reader, cinema, fps, or rts."
                exit 1
                ;;
        esac
        send_command "${COMMANDS["picture-mode"]}" "x" "$data"
        echo "Setting picture mode to $1"
        ;;
        
    "reset")
        if [ "$1" = "picture" ]; then
            send_command "${COMMANDS["reset"]}" "k" "00"
            echo "Resetting picture settings"
        elif [ "$1" = "factory" ]; then
            send_command "${COMMANDS["reset"]}" "k" "01"
            echo "Performing factory reset"
        else
            echo "Invalid reset parameter. Use 'picture' or 'factory'."
            exit 1
        fi
        ;;
        
    "list-commands")
        list_commands
        ;;
        
    *)
        echo "Unknown command: $COMMAND"
        echo "Use --help for usage information."
        exit 1
        ;;
esac

exit 0
