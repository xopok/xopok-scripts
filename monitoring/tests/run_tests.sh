#!/bin/bash
# Test runner for rrdstorm scripts
# Intercepts rrdtool/rrdupdate calls using mock executables

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${TESTS_DIR}/../.." && pwd)"
RRDSTORM_DIR="${PROJECT_DIR}/monitoring/co2/local/rrdstorm"

export RRDTOOL="${TESTS_DIR}/mock_rrdtool.sh"
export RRDUPDATE="${TESTS_DIR}/mock_rrdupdate.sh"

PASSED=0
FAILED=0

pass() {
    PASSED=$((PASSED + 1))
    echo "  PASS: $1"
}

fail() {
    FAILED=$((FAILED + 1))
    echo "  FAIL: $1"
}

assert_output_contains() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if echo "$actual" | grep -qF -- "$expected"; then
        pass "$description"
    else
        fail "$description (expected to contain: ${expected})"
    fi
}

assert_output_exact() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" = "$expected" ]; then
        pass "$description"
    else
        fail "$description (expected: ${expected}, got: ${actual})"
    fi
}

echo "=== rrdstorm test suite ==="
echo ""

# --- Test: mock executables are in place ---
echo "--- Mock executables ---"
if [ -x "${RRDTOOL}" ]; then
    pass "mock_rrdtool.sh exists and is executable"
else
    fail "mock_rrdtool.sh exists and is executable"
fi

if [ -x "${RRDUPDATE}" ]; then
    pass "mock_rrdupdate.sh exists and is executable"
else
    fail "mock_rrdupdate.sh exists and is executable"
fi

# --- Test: mock_rrdtool echoes arguments ---
echo "--- mock_rrdtool behavior ---"
MOCK_OUT=$("${RRDTOOL}" create /tmp/test.rrd --step 60 "DS:a:GAUGE:120:0:U")
assert_output_contains "echoes full command" "RRDTOOL_MOCK_EXEC: create /tmp/test.rrd --step 60" "$MOCK_OUT"

# --- Test: mock_rrdupdate echoes arguments ---
echo "--- mock_rrdupdate behavior ---"
MOCK_OUT=$("${RRDUPDATE}" /tmp/test.rrd -t "l1:l5" "1700000000:0.1:0.2")
assert_output_contains "echoes full command" "RRDUPDATE_MOCK_EXEC: /tmp/test.rrd" "$MOCK_OUT"

# --- Test: update_rrd_db.sh uses mocked RRDUPDATE ---
echo "--- update_rrd_db.sh with mocks ---"
MOCK_OUT=$("${RRDSTORM_DIR}/update_rrd_db.sh" "/tmp/test.rrd" "l1:l5:l15" "0.5:0.3:0.1")
assert_output_contains "calls mock rrdupdate" "RRDUPDATE_MOCK_EXEC:" "$MOCK_OUT"
assert_output_contains "passes rrd file path" "/tmp/test.rrd" "$MOCK_OUT"
assert_output_contains "passes data sources" "-t l1:l5:l15" "$MOCK_OUT"

# --- Test: wrapper.sh help command ---
echo "--- wrapper.sh help ---"
HELP_OUT=$("${RRDSTORM_DIR}/wrapper.sh" help)
assert_output_contains "help mentions create" "create" "$HELP_OUT"
assert_output_contains "help mentions update" "update" "$HELP_OUT"
assert_output_contains "help mentions graph" "graph" "$HELP_OUT"

# --- Test: wrapper.sh create (mocked) ---
echo "--- wrapper.sh create with mocks ---"
MOCK_RRDOUTPUT=$(mktemp -d)
MOCK_RRDDATA=$(mktemp -d)
MOCK_OUT=$(RRDOUTPUT="${MOCK_RRDOUTPUT}" RRDDATA="${MOCK_RRDDATA}" \
    "${RRDSTORM_DIR}/wrapper.sh" create 0 2>/dev/null || true)
assert_output_contains "create outputs var info" "Vars:" "$MOCK_OUT"

CREATE_OUT=$(RRDOUTPUT="${MOCK_RRDOUTPUT}" RRDDATA="${MOCK_RRDDATA}" \
    "${RRDSTORM_DIR}/wrapper.sh" create 0 2>&1 || true)
assert_output_contains "calls mock rrdtool create" "RRDTOOL_MOCK_EXEC: create" "$CREATE_OUT"
rm -rf "${MOCK_RRDOUTPUT}" "${MOCK_RRDDATA}"

# --- Test: wrapper.sh update (mocked) ---
echo "--- wrapper.sh update with mocks ---"
MOCK_RRDDATA=$(mktemp -d)
UPDATE_OUT=$(RRDDATA="${MOCK_RRDDATA}" \
    "${RRDSTORM_DIR}/wrapper.sh" update 0 2>&1 || true)
assert_output_contains "calls mock rrdupdate" "RRDUPDATE_MOCK_EXEC:" "$UPDATE_OUT"
rm -rf "${MOCK_RRDDATA}"

# --- Test: data extractors ---
test_data_extractors() {
    echo "--- Data extractors ---"
    local DATA_DIR="${RRDSTORM_DIR}/data"
    local found=0

    for script in "${DATA_DIR}"/*.sh; do
        [ -f "$script" ] || continue
        found=$((found + 1))
        local basename
        basename=$(basename "$script" .sh)

        # Execute and capture output + exit status (|| true avoids set -e abort)
        local out status
        out=$("$script" 2>/dev/null) && status=0 || status=$?

        if [ "$status" -ne 0 ]; then
            fail "data/${basename}.sh exits cleanly (exit code: ${status})"
            continue
        fi

        if [ -z "$out" ]; then
            fail "data/${basename}.sh produces non-empty output"
            continue
        fi

        local trimmed
        trimmed=$(echo "$out" | sed '/^[[:space:]]*$/d' | tr '\n' '|')
        local clean
        clean=$(echo "$out" | tr -d '\n')
        if [ -z "$clean" ]; then
            fail "data/${basename}.sh produces non-empty output (after stripping newlines)"
            continue
        fi
        if ! echo "$clean" | grep -qE '^[a-zA-Z0-9.:_-]+$'; then
            fail "data/${basename}.sh output matches format regex (got: ${out})"
            continue
        fi

        pass "data/${basename}.sh format and exit status"
    done

    if [ "$found" -eq 0 ]; then
        fail "No data extractor scripts found in ${DATA_DIR}"
    fi
}

test_data_extractors

# --- Test: standalone updater ---
test_standalone_updater() {
    echo "--- Standalone updater ---"
    local DB_PATH="/tmp/fake_db.rrd"
    local DS="ds1:ds2"
    local VALS="100:200"

    local out
    out=$("${RRDSTORM_DIR}/update_rrd_db.sh" "$DB_PATH" "$DS" "$VALS")

    # Assert starts with mock prefix
    if echo "$out" | grep -qF -- "RRDUPDATE_MOCK_EXEC:"; then
        pass "output starts with RRDUPDATE_MOCK_EXEC:"
    else
        fail "output starts with RRDUPDATE_MOCK_EXEC: (got: ${out})"
        return
    fi

    # Assert DB path and data sources are present
    if echo "$out" | grep -qF -- "$DB_PATH"; then
        pass "output contains DB path"
    else
        fail "output contains DB path (expected: ${DB_PATH})"
    fi

    if echo "$out" | grep -qF -- "-t ${DS}"; then
        pass "output contains data sources"
    else
        fail "output contains data sources (expected: -t ${DS})"
    fi

    # Extract timestamp: last arg is <ts>:100:200
    local ts_arg
    ts_arg=$(echo "$out" | awk '{print $NF}')
    local ts_val="${ts_arg%:${VALS}}"

    if [[ "$ts_val" =~ ^[0-9]+$ ]] && [ "$ts_val" -gt 0 ] && [ "$((ts_val % 60))" -eq 0 ]; then
        pass "timestamp is valid unix timestamp rounded to minute (${ts_val})"
    else
        fail "timestamp is valid and rounded to minute (got: ${ts_val} from ${ts_arg})"
    fi
}

test_standalone_updater

# --- Test: graph generation ---
test_graph_generation() {
    echo "--- Graph generation (N=0, P=0) ---"

    local N=0
    local P=0
    local DEFSDIR="${RRDSTORM_DIR}/defs"
    local META_FILE="${DEFSDIR}/0-load.meta"
    local DEF_FILE="${DEFSDIR}/0-load.sh"
    local RRDFILE="/tmp/fake_load.rrd"

    # Source the .meta file
    if ! source "$META_FILE" 2>/dev/null; then
        fail "0-load.meta sources cleanly"
        return
    fi
    pass "0-load.meta sources cleanly"

    # Verify that RRDgGRAPH[0] is defined by the meta file
    if [ -z "${RRDgGRAPH[$P]}" ]; then
        fail "RRDgGRAPH[${P}] is defined after sourcing meta"
        return
    fi
    pass "RRDgGRAPH[${P}] is defined after sourcing meta"

    # Parse RRDgGRAPH[P] exactly like CreateGraph does
    local BACK IMGBASE TITLE EXTRA COND
    BACK=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f1)
    IMGBASE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f2)
    TITLE=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f3)
    EXTRA=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f5)
    COND=$(echo "${RRDgGRAPH[$P]}" | cut -d'|' -f4)

    # Build GRAPH_ARGS from def file, replacing $RRD (mimics CreateGraph)
    local GRAPH_ARGS=()
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        line="${line//\$RRD/$RRDFILE}"
        GRAPH_ARGS+=("$line")
    done < "$DEF_FILE"

    # Execute the mock rrdtool graph command
    local out
    out=$("${RRDTOOL}" graph "/tmp/${IMGBASE}.svg" \
        -M -a SVG -s "-${BACK}" -e -20 -w 550 -h 240 \
        -v "${RRDgUM[$N]}" -t "$TITLE" \
        --graph-render-mode normal \
        --color CANVAS#000000 --color FONT#FFFFFF --color BACK#000000 \
        "${GRAPH_ARGS[@]}")

    # Assertion: output starts with mock prefix and contains "graph"
    if echo "$out" | grep -qF -- "RRDTOOL_MOCK_EXEC: graph"; then
        pass "output contains RRDTOOL_MOCK_EXEC: graph"
    else
        fail "output contains RRDTOOL_MOCK_EXEC: graph (got: ${out:0:80})"
    fi

    # Assertion: $RRD was replaced (should NOT appear literally in output)
    if echo "$out" | grep -qF -- '$RRD'; then
        fail "literal \$RRD was replaced in def file (still found \$RRD in output)"
    else
        pass "literal \$RRD was replaced in def file"
    fi

    # Assertion: the replacement value appears
    if echo "$out" | grep -qF -- "$RRDFILE"; then
        pass "replacement value ${RRDFILE} appears in output"
    else
        fail "replacement value ${RRDFILE} appears in output"
    fi
}

test_graph_generation

# --- Summary ---
echo ""
echo "=== Results: ${PASSED} passed, ${FAILED} failed ==="

if [ "${FAILED}" -gt 0 ]; then
    exit 1
fi
exit 0
