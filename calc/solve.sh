#!/bin/bash
# solve.sh -- bc command line wrapper

bc << EOF
scale=12
$@
quit
EOF
