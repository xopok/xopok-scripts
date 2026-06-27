#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

setup() {
    MOCK_DIR="$(mktemp -d)"
    RRDOUTPUT_DIR="$(mktemp -d)"

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
    chmod +x "${MOCK_DIR}/rrdtool" "${MOCK_DIR}/rrdupdate"

    export PATH="${MOCK_DIR}:${PATH}"
    export RRDTOOL="rrdtool"
    export RRDUPDATE="rrdupdate"
    export RRDOUTPUT="${RRDOUTPUT_DIR}"
    export FORCEGRAPH="yes"
}

teardown() {
    rm -rf "${MOCK_DIR:?}" "${RRDOUTPUT_DIR:?}"
}

@test "wrapper.sh accurately constructs rrdtool graph command" {
    run "${RRDSTORM_DIR}/wrapper.sh" graph_cron s 0

    [ "$status" -eq 0 ]

    [[ "$output" == *"MOCK_RRDTOOL: graph"* ]]

    [[ "$output" == *"DEF:ds1=/var/lib/rrd/storj/load.rrd:l1:AVERAGE"* ]]

    [[ "$output" == *"System load, last hour @"* ]]
}
