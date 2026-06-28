#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

setup() {
    MOCK_DIR="$(mktemp -d)"
    RRDOUTPUT_DIR="$(mktemp -d)"

    cat > "${MOCK_DIR}/rrdtool" <<'EOF'
#!/bin/bash
echo "$@"
EOF
    chmod +x "${MOCK_DIR}/rrdtool"

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

    export PATH="${MOCK_DIR}:${PATH}"
    export RRDTOOL="rrdtool"
    export FORCEGRAPH="yes"
    export RRDOUTPUT="${RRDOUTPUT_DIR}"
}

teardown() {
    rm -rf "${MOCK_DIR:?}" "${RRDOUTPUT_DIR:?}"
}

@test "wrapper.sh output perfectly matches rrdstorm.sh output" {
    OLD_OUTPUT=$(cd "${RRDSTORM_DIR}" && bash rrdstorm.sh graph_cron s 0 2>/dev/null)
    NEW_OUTPUT=$(cd "${RRDSTORM_DIR}" && bash wrapper.sh graph_cron s 0 2>/dev/null)

    [ "$OLD_OUTPUT" = "$NEW_OUTPUT" ] || {
        echo "OUTPUTS DO NOT MATCH!"
        echo "=== OLD (rrdstorm.sh) ==="
        echo "$OLD_OUTPUT"
        echo "=== NEW (wrapper.sh) ==="
        echo "$NEW_OUTPUT"
        false
    }
}
