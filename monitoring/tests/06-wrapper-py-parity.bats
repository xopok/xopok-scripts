#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"
TEST_RRDOUTPUT="/tmp/rrdstorm_test_output"

setup() {
    MOCK_DIR="$(mktemp -d)"
    RRDOUTPUT_DIR="${TEST_RRDOUTPUT}"
    mkdir -p "${RRDOUTPUT_DIR}"

    # Mock rrdtool: echoes all arguments to stdout
    cat > "${MOCK_DIR}/rrdtool" <<'EOF'
#!/bin/bash
echo "$@"
EOF
    chmod +x "${MOCK_DIR}/rrdtool"

    # Mock date: deterministic time for graph conditions
    cat > "${MOCK_DIR}/date" <<'EOF'
#!/bin/bash
if [ "$1" = "+%M" ]; then
    echo "30"
elif [ "$1" = "+%H" ]; then
    echo "12"
else
    /bin/date "$@"
fi
EOF
    chmod +x "${MOCK_DIR}/date"

    # Mock update_rrd_db.sh: echoes the call
    cat > "${MOCK_DIR}/update_rrd_db.sh" <<'EOF'
#!/bin/bash
echo "update_rrd_db.sh $1 $2 $3"
EOF
    chmod +x "${MOCK_DIR}/update_rrd_db.sh"

    export PATH="${MOCK_DIR}:${PATH}"
    export RRDTOOL="rrdtool"
    export FORCEGRAPH="yes"
    export RRDOUTPUT="${RRDOUTPUT_DIR}"
}

teardown() {
    rm -rf "${MOCK_DIR:?}" "${TEST_RRDOUTPUT:?}"
}

run_python() {
    export RRDOUTPUT="${TEST_RRDOUTPUT}"
    export WRAP_TIME_OVERRIDE="12:30"
    python3 "${RRDSTORM_DIR}/wrapper.py" "$@" 2>/dev/null
}

run_bash() {
    export RRDOUTPUT="${TEST_RRDOUTPUT}"
    bash "${RRDSTORM_DIR}/wrapper.sh" "$@" 2>/dev/null
}

@test "wrapper.py and wrapper.sh produce identical help output" {
    PY_OUTPUT=$(run_python help)
    SH_OUTPUT=$(run_bash help)

    [ "$PY_OUTPUT" = "$SH_OUTPUT" ] || {
        echo "OUTPUTS DO NOT MATCH!"
        echo "=== PYTHON ==="
        echo "$PY_OUTPUT"
        echo "=== BASH ==="
        echo "$SH_OUTPUT"
        false
    }
}

@test "wrapper.py and wrapper.sh produce identical graph_cron output for all indices" {
    for i in {0..9}; do
        rm -rf "${TEST_RRDOUTPUT:?}"/*
        PY_OUTPUT=$(run_python graph_cron s "$i")
        SH_OUTPUT=$(run_bash graph_cron s "$i")

        [ "$PY_OUTPUT" = "$SH_OUTPUT" ] || {
            echo "OUTPUTS DO NOT MATCH FOR INDEX $i!"
            echo "=== PYTHON ==="
            echo "$PY_OUTPUT"
            echo "=== BASH ==="
            echo "$SH_OUTPUT"
            false
        }
    done
}

@test "wrapper.py and wrapper.sh produce identical graph output for all indices" {
    for i in {0..9}; do
        rm -rf "${TEST_RRDOUTPUT:?}"/*
        PY_OUTPUT=$(run_python graph "$i")
        SH_OUTPUT=$(run_bash graph "$i")

        [ "$PY_OUTPUT" = "$SH_OUTPUT" ] || {
            echo "OUTPUTS DO NOT MATCH FOR INDEX $i!"
            echo "=== PYTHON ==="
            echo "$PY_OUTPUT"
            echo "=== BASH ==="
            echo "$SH_OUTPUT"
            false
        }
    done
}

@test "wrapper.py handles invalid command like wrapper.sh" {
    run python3 "${RRDSTORM_DIR}/wrapper.py" fake_command 0 2>&1
    PY_OUTPUT="$output"
    PY_STATUS="$status"

    run bash "${RRDSTORM_DIR}/wrapper.sh" fake_command 0 2>&1
    SH_OUTPUT="$output"
    SH_STATUS="$status"

    [[ "$PY_OUTPUT" == *"ERROR: Unknown command"* ]]
    [[ "$SH_OUTPUT" == *"ERROR: Unknown command"* ]]
    [ "$PY_STATUS" -eq 1 ]
    [ "$SH_STATUS" -eq 1 ]
}

@test "wrapper.py graph_cron with invalid time fails like wrapper.sh" {
    run python3 "${RRDSTORM_DIR}/wrapper.py" graph_cron x 0 2>&1
    PY_STATUS="$status"

    run bash "${RRDSTORM_DIR}/wrapper.sh" graph_cron x 0 2>&1
    SH_STATUS="$status"

    [ "$PY_STATUS" -eq 1 ]
    [ "$SH_STATUS" -eq 1 ]
}

@test "wrapper.py handles missing metadata like wrapper.sh" {
    PY_OUTPUT=$(python3 "${RRDSTORM_DIR}/wrapper.py" update 999 2>&1)
    SH_OUTPUT=$(bash "${RRDSTORM_DIR}/wrapper.sh" update 999 2>&1)

    [[ "$PY_OUTPUT" == *"No metadata file found for index 999"* ]]
    [[ "$SH_OUTPUT" == *"No metadata file found for index 999"* ]]
}
