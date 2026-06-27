#!/bin/bash
# Data extraction: Average system load
# Usage: ./data/0-load.sh
# Output: colon-separated values: L1:L5:L15
UT=$(head -n1 /proc/loadavg)
L1=$(echo "$UT"|awk "{print \$1}")
L5=$(echo "$UT"|awk "{print \$2}")
L15=$(echo "$UT"|awk "{print \$3}")
echo "${L1}:${L5}:${L15}"
