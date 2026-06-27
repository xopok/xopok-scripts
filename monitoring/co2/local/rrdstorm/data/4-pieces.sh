#!/bin/bash
# Data extraction: Storj upload and download statistics
# Usage: ./data/4-pieces.sh
# Output: colon-separated values: upload:uploaded:uploadfailed:download:downloaded:downloadfailed:audit:audited:auditfailed:deleted
LOG=`sudo docker logs --since 1m storagenode0 2>&1; sudo docker logs --since 1m storagenode1 2>&1; sudo docker logs --since 1m storagenode2 2>&1; sudo docker logs --since 1m storagenode3 2>&1`
UPLOAD=$(echo "$LOG" | grep -c "upload started" | xargs -n 1 expr 60 \*)
UPLOADED=$(echo "$LOG" | grep -c "uploaded" | xargs -n 1 expr 60 \*)
UPLOADFAILED=$(echo "$LOG" | grep -c "upload [a-z]*led" | xargs -n 1 expr 60 \*)
DOWNLOAD=$(echo "$LOG" | grep -c "download started" | xargs -n 1 expr 60 \*)
DOWNLOADED=$(echo "$LOG" | grep -c "downloaded" | xargs -n 1 expr 60 \*)
DOWNLOADFAILED=$(echo "$LOG" | grep -c "download failed" | xargs -n 1 expr 60 \*)
AUDIT=$(echo "$LOG" | grep -c "download started.*GET_AUDIT" | xargs -n 1 expr 60 \*)
AUDITED=$(echo "$LOG" | grep -c "downloaded.*GET_AUDIT" | xargs -n 1 expr 60 \*)
AUDITFAILED=$(echo "$LOG" | grep -c "download failed.*GET_AUDIT" | xargs -n 1 expr 60 \*)
DELETED=$(echo "$LOG" | grep -c "delete " | xargs -n 1 expr 60 \*)
echo "${UPLOAD}:${UPLOADED}:${UPLOADFAILED}:${DOWNLOAD}:${DOWNLOADED}:${DOWNLOADFAILED}:${AUDIT}:${AUDITED}:${AUDITFAILED}:${DELETED}"
