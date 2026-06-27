#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

setup() {
    MOCK_DIR="$(mktemp -d)"

    cat > "${MOCK_DIR}/rrdupdate" <<'EOF'
#!/bin/bash
echo "MOCK_RRDUPDATE: $@"
exit 0
EOF
    chmod +x "${MOCK_DIR}/rrdupdate"

    export PATH="${MOCK_DIR}:${PATH}"
    export RRDUPDATE="rrdupdate"
}

teardown() {
    rm -rf "${MOCK_DIR:?}"
}

@test "update_rrd_db.sh constructs valid rrdupdate command" {
    run "${RRDSTORM_DIR}/update_rrd_db.sh" "/tmp/test.rrd" "ds1:ds2" "10:20"

    [ "$status" -eq 0 ]

    [[ "$output" == "MOCK_RRDUPDATE: /tmp/test.rrd -t ds1:ds2 "* ]]
    [[ "$output" =~ [0-9]{10}:10:20$ ]]
}
