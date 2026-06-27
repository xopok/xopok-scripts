#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

setup() {
    MOCK_DIR="$(mktemp -d)"

    cat > "${MOCK_DIR}/sudo" <<'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "${MOCK_DIR}/sudo"

    export PATH="${MOCK_DIR}:${PATH}"
}

teardown() {
    rm -rf "${MOCK_DIR:?}"
}

@test "All data extractors output colon-separated values" {
    for script in "${RRDSTORM_DIR}"/data/*.sh; do
        [ -f "$script" ] || continue

        basename=$(basename "$script" .sh)

        run bash -c "exec < /dev/null; '$script' 2>/dev/null"
        [ "$status" -eq 0 ] || {
            echo "FAIL: data/${basename}.sh exited with status ${status}"
            return 1
        }

        [[ "$output" =~ ^[a-zA-Z0-9.:_-]+$ ]] || {
            echo "FAIL: data/${basename}.sh output format invalid (got: '${output}')"
            return 1
        }
    done
}
