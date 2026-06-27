#!/bin/bash
# Data extraction: WAN traffic
# Usage: ./data/6-wan.sh
# Output: colon-separated values: in:out:dockin:dockout
IF="eno1:"
IN=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$1}")
OUT=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$9}")
IF="docker0:"
DOCKIN=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$1}")
DOCKOUT=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$9}")
echo "${IN}:${OUT}:${DOCKIN}:${DOCKOUT}"
