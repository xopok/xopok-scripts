#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

setup() {
    MOCK_DIR="$(mktemp -d)"
    RRDOUTPUT_DIR="$(mktemp -d)"

    # Mock rrdtool: echoes all arguments to stdout
    cat > "${MOCK_DIR}/rrdtool" <<'EOF'
#!/bin/bash
echo "MOCK_RRDTOOL: $@"
exit 0
EOF

    cat > "${MOCK_DIR}/rrdupdate" <<'EOF'
#!/bin/bash
echo "MOCK_RRDUPDATE: $@"
exit 0
EOF

    # Mock date: deterministic time for render conditions
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

    chmod +x "${MOCK_DIR}/rrdtool" "${MOCK_DIR}/rrdupdate" "${MOCK_DIR}/date"

    export PATH="${MOCK_DIR}:${PATH}"
    export RRDTOOL="rrdtool"
    export RRDUPDATE="rrdupdate"
    export RRDOUTPUT="${RRDOUTPUT_DIR}"
    export FORCEGRAPH="yes"
}

teardown() {
    rm -rf "${MOCK_DIR:?}" "${RRDOUTPUT_DIR:?}"
}

@test "wrapper.sh output perfectly matches rrdstorm.sh output" {
    # rrdstorm.sh hardcodes RRDTOOL, RRDUPDATE, RRDOUTPUT, FORCEGRAPH.
    # Patch them to respect environment variables so our mocks take effect.
    PATCHED_RRDSTORM="${MOCK_DIR}/rrdstorm.sh"
    sed \
        -e 's|^RRDTOOL=/usr/bin/rrdtool|RRDTOOL="${RRDTOOL:-/usr/bin/rrdtool}"|' \
        -e 's|^RRDUPDATE=/usr/bin/rrdupdate|RRDUPDATE="${RRDUPDATE:-/usr/bin/rrdupdate}"|' \
        -e 's|^RRDOUTPUT=/dev/shm/rrd.img|RRDOUTPUT="${RRDOUTPUT:-/dev/shm/rrd.img}"|' \
        -e 's|^FORCEGRAPH=no|FORCEGRAPH="${FORCEGRAPH:-no}"|' \
        "${RRDSTORM_DIR}/rrdstorm.sh" > "$PATCHED_RRDSTORM"
    chmod +x "$PATCHED_RRDSTORM"

    run "$PATCHED_RRDSTORM" graph_cron s 0
    OLD_OUTPUT="$output"

    run "${RRDSTORM_DIR}/wrapper.sh" graph_cron s 0
    NEW_OUTPUT="$output"

    if [ "$OLD_OUTPUT" != "$NEW_OUTPUT" ]; then
        echo "--- OLD (rrdstorm.sh) ---"
        echo "$OLD_OUTPUT"
        echo "--- NEW (wrapper.sh) ---"
        echo "$NEW_OUTPUT"
        echo "--- DIFF ---"
        diff <(echo "$OLD_OUTPUT") <(echo "$NEW_OUTPUT")
    fi

    [ "$OLD_OUTPUT" = "$NEW_OUTPUT" ]
}
