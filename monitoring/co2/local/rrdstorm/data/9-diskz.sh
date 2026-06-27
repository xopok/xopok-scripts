#!/bin/bash
# Data extraction: Disk IO usage (hdd3 + hdd4)
# Usage: ./data/9-diskz.sh
# Output: colon-separated values: ar:arm:ars:aw:awm:aws:cr:crm:crs:cw:cwm:cws
echo -n $(cat /sys/block/`readlink /dev/disk/by-id/wwn-0x5000cca2a1f3cc93 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}"):
echo    $(cat /sys/block/`readlink /dev/disk/by-id/wwn-0x5000cca295e13211 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}")
