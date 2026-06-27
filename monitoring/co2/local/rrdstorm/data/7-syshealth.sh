#!/bin/bash
# Data extraction: System health (CPU/HDD/SSD temperature)
# Usage: ./data/7-syshealth.sh
# Output: colon-separated values: tcpu:thdd:tssd
TCPU=$(cat /sys/class/thermal/thermal_zone0/temp | awk "{printf \"%.1f\", \$1/1000}")
THDD1=$(smartctl --nocheck=standby -d sat -A /dev/disk/by-id/wwn-0x5000cca28de6971f | grep "Celsius" | awk "{print \$10;}")
THDD2=$(smartctl --nocheck=standby -d sat -A /dev/disk/by-id/wwn-0x5000cca264d3b9b0 | grep "Celsius" | awk "{print \$10;}")
echo "${TCPU}:${THDD1:-U}:${THDD2:-U}"
