#!/bin/bash
# Data extraction: Disk IO usage (hdd1 + hdd2 + ssd)
# Usage: ./data/3-disks.sh
# Output: colon-separated values: ar:arm:ars:aw:awm:aws:cr:crm:crs:cw:cwm:cws:br:brm:brs:bw:bwm:bws:dr:drm:drs:dw:dwm:dws
echo -n $(cat /sys/block/`readlink /dev/disk/by-id/wwn-0x5000cca28de6971f | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}"):
echo -n $(cat /sys/block/`readlink /dev/disk/by-id/wwn-0x5000cca264d3b9b0 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}"):
echo -n $(cat /sys/block/`readlink /dev/disk/by-id/nvme-eui.002538b631b35148 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}"):
echo    $(cat /sys/block/`readlink /dev/disk/by-id/wwn-0x5000cca2a1f3cc93 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}")
