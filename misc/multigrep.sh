#!/bin/bash
# multigrep.sh - Read multiline input, grep a file for each line
# Usage: multigrep.sh <file>

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

if [[ ! -f "$1" ]]; then
    echo "Error: '$1' is not a file" >&2
    exit 1
fi

echo "Enter search terms (one per line, Ctrl-D when done):"
lines=()
while IFS= read -r line; do
    [[ -n "$line" ]] && lines+=("$line")
done

if [[ ${#lines[@]} -eq 0 ]]; then
    echo "No input provided" >&2
    exit 1
fi

# Build alternation pattern from array
pattern=$(printf '%s\n' "${lines[@]}" | paste -sd '|')
grep -En "$pattern" "$1"
