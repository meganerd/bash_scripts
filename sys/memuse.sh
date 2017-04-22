#!/bin/bash
# Brief output.  Will be a parameter option in an upcoming revision
#smem -t -k -c pss -P $1 | tail -n 1

smem -t -k -P $1 
