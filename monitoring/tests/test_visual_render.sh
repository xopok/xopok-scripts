#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RRDSTORM_DIR="${SCRIPT_DIR}/../co2/local/rrdstorm"

TEST_ROOT="/tmp/rrd_test_env"
rm -rf "${TEST_ROOT}"
mkdir -p "${TEST_ROOT}"

export RRDDATA="${TEST_ROOT}"
export RRDOUTPUT="${TEST_ROOT}"
export FORCEGRAPH="yes"

echo "=== Step 1: Create RRD database ==="
"${RRDSTORM_DIR}/wrapper.sh" create 0

RRD_FILE="${TEST_ROOT}/load.rrd"
if [ ! -f "$RRD_FILE" ]; then
    echo "FAIL: RRD database not created at ${RRD_FILE}"
    exit 1
fi
echo "OK: Database created"

echo ""
echo "=== Step 2: Inject 15 mock data points ==="
NOW=$(date +%s)
for i in $(seq 0 14); do
    TS=$(( NOW + i*60 ))
    L1=$(echo "scale=2; 0.5 + $i * 0.3" | bc)
    L5=$(echo "scale=2; 0.3 + $i * 0.15" | bc)
    L15=$(echo "scale=2; 0.1 + $i * 0.08" | bc)
    VALS="${L1}:${L5}:${L15}"
    rrdtool update "$RRD_FILE" -t "l1:l5:l15" "${TS}:${VALS}"
    echo "  t=${TS} -> ${VALS}"
done

echo ""
echo "=== Step 3: Generate 1-hour graph ==="
"${RRDSTORM_DIR}/wrapper.sh" graph_cron s 0

SVG_FILE="${TEST_ROOT}/load1.svg"
if [ -f "$SVG_FILE" ]; then
    SIZE=$(wc -c < "$SVG_FILE")
    echo "OK: Graph rendered at ${SVG_FILE} (${SIZE} bytes)"
else
    echo "FAIL: SVG not found at ${SVG_FILE}"
    exit 1
fi

echo ""
echo "=== Done ==="
