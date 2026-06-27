#!/bin/bash
# Data extraction: Disk space
# Usage: ./data/5-hdd.sh
# Output: colon-separated values: rootfree:rootused:placefree:placeused:placestorj
echo -n $(df -B1 / | tail -n 1 | awk "{print \$4\":\"\$3}"):
echo -n $(df -B1 /place4 | tail -n +2 | awk "{ s = s + \$4; } END { printf \"%17.0f\", s; }"):
TOTAL=$(df -B1 /place4 | tail -n +2 | awk "{ s = s + \$3; } END { printf \"%17.0f\", s; }")
OTHER=$(du -sx -B1 --exclude "/place4/storj*" /place[1-9] | awk "{ s = s + \$1; } END { printf \"%17.0f\", s; }")
echo ${TOTAL}:$(expr $TOTAL - $OTHER)
