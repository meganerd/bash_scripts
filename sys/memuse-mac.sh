#!/bin/sh

# Check if osquery is available
if ! command -v osqueryi >/dev/null 2>&1; then
    echo "Error: osquery is not installed or not in PATH"
    exit 1
fi

# Run osquery with CSV output and process with awk
osqueryi --csv "SELECT pid, name, cmdline, CAST(resident_size / (1024 * 1024) AS INTEGER) AS memory_mb FROM processes ORDER BY resident_size DESC LIMIT 10;" | \
awk -F'|' '
BEGIN { 
    print "\nTop 10 Processes by Memory Usage\n"
    print "PID     Process Name              Command Line                                     Memory MB"
    print "-----   -----------------------   ----------------------------------------------   ---------"
}
NR>1 {
    # Remove quotes from CSV fields
    gsub(/"/, "", $1)
    gsub(/"/, "", $2)
    gsub(/"/, "", $3)
    gsub(/"/, "", $4)
    
    # Truncate long command lines
    cmdline = $3
    if (length(cmdline) > 45) {
        cmdline = substr(cmdline, 1, 42) "..."
    }
    
    # Format the output
    printf("%-7s %-23s %-45s %9s MB\n", $1, $2, cmdline, $4)
}'
