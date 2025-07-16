#!/bin/sh

# Set default number of processes
NUM_PROCESSES=15
SHOW_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n)
            NUM_PROCESSES="$2"
            shift 2
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-n number_of_processes] [--all]"
            echo "  -n NUM    Show top NUM processes (default: 15)"
            echo "  --all     Show all processes"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [-n number_of_processes] [--all]" >&2
            exit 1
            ;;
    esac
done

# Check if osquery is available
if ! command -v osqueryi >/dev/null 2>&1; then
    echo "Error: osquery is not installed or not in PATH"
    exit 1
fi

# Build the SQL query
if [ "$SHOW_ALL" = true ]; then
    QUERY="SELECT pid, name, cmdline, CAST(resident_size / (1024 * 1024) AS INTEGER) AS memory_mb FROM processes ORDER BY resident_size DESC;"
else
    QUERY="SELECT pid, name, cmdline, CAST(resident_size / (1024 * 1024) AS INTEGER) AS memory_mb FROM processes ORDER BY resident_size DESC LIMIT $NUM_PROCESSES;"
fi

# Run osquery with CSV output and process with awk
osqueryi --csv "$QUERY" | \
awk -F'|' -v num_processes="$NUM_PROCESSES" -v show_all="$SHOW_ALL" '
BEGIN { 
    if (show_all == "true") {
        print "\nAll Processes by Memory Usage\n"
    } else {
        print "\nTop " num_processes " Processes by Memory Usage\n"
    }
    print "PID     Process Name              Command Line                                     Memory MB"
    print "-----   -----------------------   ----------------------------------------------   ---------"
    total_memory = 0
    process_count = 0
}
NR>1 {
    # Remove quotes from CSV fields
    gsub(/"/, "", $1)
    gsub(/"/, "", $2)
    gsub(/"/, "", $3)
    gsub(/"/, "", $4)
    
    # Add to totals
    total_memory += $4
    process_count++
    
    # Truncate long command lines
    cmdline = $3
    if (length(cmdline) > 45) {
        cmdline = substr(cmdline, 1, 42) "..."
    }
    
    # Format the output
    printf("%-7s %-23s %-45s %9s MB\n", $1, $2, cmdline, $4)
}
END {
    if (process_count > 0) {
        print "-----   -----------------------   ----------------------------------------------   ---------"
        printf("Total: %d processes using %d MB of memory\n", process_count, total_memory)
    }
}'
