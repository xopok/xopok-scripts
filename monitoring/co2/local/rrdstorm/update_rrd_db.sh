#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

T=$(date +%s)
T=$(expr $T / 60 \* 60)
"$RRDUPDATE" "$1" -t "$2" "$T:${3}"
